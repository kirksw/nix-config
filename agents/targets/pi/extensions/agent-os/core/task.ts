/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { parseMarkdownDocument, writeMarkdownDocument } from "./markdown-store.ts";
import type { TaskRecord, TaskStatus } from "./schema.ts";
import { slugify } from "./slug.ts";

export type { TaskRecord, TaskStatus } from "./schema.ts";

export interface TaskBinding {
	id: string;
	path: string;
	packagePath: string;
}

export type FactoryRunLauncher = (task: TaskRecord, runReportPath: string) => Promise<void>;

export interface FactoryRun {
	task: TaskRecord;
	runReportPath: string;
}

export type RunOutcome = "success" | "failure";

export interface TaskRunOutcome {
	outcome: RunOutcome;
	completedAt?: string;
}

export const TASK_STATUSES: readonly TaskStatus[] = ["draft", "specced", "running", "review", "done", "failed"];
export const TASK_TRANSITIONS: Readonly<Record<TaskStatus, readonly TaskStatus[]>> = {
	draft: ["specced"],
	specced: ["running"],
	running: ["review"],
	review: ["done", "failed"],
	done: [],
	failed: [],
};

const BUNDLE_DIRECTORIES = ["input", "runs", "artifacts"] as const;

function inside(root: string, candidate: string): boolean {
	const relative = path.relative(path.resolve(root), path.resolve(candidate));
	return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function validSegment(value: string): boolean {
	return Boolean(value && value !== "." && value !== ".." && !value.includes("/") && !value.includes("\\"));
}

function validStatus(value: unknown): value is TaskStatus {
	return typeof value === "string" && (TASK_STATUSES as readonly string[]).includes(value);
}

function validTimestamp(value: unknown): value is string {
	return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

export function validateTaskStatus(value: unknown): asserts value is TaskStatus {
	if (!validStatus(value)) throw new Error(`invalid task status: ${String(value)}`);
}

export function canTransitionTask(from: TaskStatus, to: TaskStatus): boolean {
	validateTaskStatus(from);
	validateTaskStatus(to);
	return TASK_TRANSITIONS[from].includes(to);
}

async function validateBundle(root: string): Promise<void> {
	const stat = await fs.stat(root).catch(() => undefined);
	if (!stat?.isDirectory()) throw new Error(`task bundle not found: ${root}`);
	const packageStat = await fs.stat(path.join(root, "package.md")).catch(() => undefined);
	if (!packageStat?.isFile()) throw new Error(`non-canonical task bundle (package.md is not a file): ${root}`);
	const entries = await fs.readdir(root);
	for (const required of ["package.md", ...BUNDLE_DIRECTORIES]) {
		if (!entries.includes(required)) throw new Error(`non-canonical task bundle (missing ${required}): ${root}`);
	}
	for (const entry of entries) {
		if (entry !== "package.md" && !(BUNDLE_DIRECTORIES as readonly string[]).includes(entry)) {
			throw new Error(`non-canonical task bundle (unexpected ${entry}): ${root}`);
		}
	}
	for (const directory of BUNDLE_DIRECTORIES) {
		if (!(await fs.stat(path.join(root, directory)).catch(() => undefined))?.isDirectory()) {
			throw new Error(`non-canonical task bundle (${directory} is not a directory): ${root}`);
		}
	}
}

async function packageMetadata(packagePath: string, fallback: string): Promise<TaskRecord> {
	const document = parseMarkdownDocument(packagePath, await fs.readFile(packagePath, "utf8").catch(() => ""));
	const fm = document.frontmatter;
	const bundle = path.dirname(packagePath);
	if (String(fm.type ?? "").toLowerCase() !== "task") throw new Error(`invalid task type: ${bundle}`);
	if (typeof fm.id !== "string" || !fm.id) throw new Error(`task id is required: ${bundle}`);
	if (typeof fm.title !== "string" || !fm.title) throw new Error(`task title is required: ${bundle}`);
	if (typeof fm.thread !== "string" || !fm.thread) throw new Error(`task thread is required: ${bundle}`);
	if (typeof fm.status !== "string") throw new Error(`task status is required: ${bundle}`);
	const id = fm.id;
	const title = fm.title;
	const status = fm.status;
	validateTaskStatus(status);
	const created = fm.createdAt ?? fm.timestamp;
	if (!validTimestamp(created)) throw new Error(`task createdAt is required: ${bundle}`);
	if (fm.updatedAt !== undefined && !validTimestamp(fm.updatedAt)) throw new Error(`task updatedAt is invalid: ${bundle}`);
	return {
		id,
		type: "task",
		title,
		thread: fm.thread,
		status,
		createdAt: created,
		updatedAt: typeof fm.updatedAt === "string" ? fm.updatedAt : undefined,
		path: bundle,
		packagePath,
		goal: typeof fm.goal === "string" ? fm.goal : undefined,
		notes: typeof fm.notes === "string" ? fm.notes : undefined,
	};
}

export async function resolveTask(workspacePath: string, thread: string, input: string): Promise<TaskRecord> {
	if (!validSegment(thread)) throw new Error("task must belong to a directory-safe thread");
	const root = path.resolve(workspacePath, "threads", thread, "tasks");
	const value = input.trim();
	if (!value) throw new Error("usage: /agent-os task <id|path|clear>");
	if (value === "clear") throw new Error("clear is not a task");
	const workspaceRelative = `threads/${thread}/tasks/`;
	let candidate = path.resolve(path.isAbsolute(value) ? value : value.startsWith(workspaceRelative) ? path.join(workspacePath, value) : path.join(root, value));
	if (!inside(root, candidate)) throw new Error("task must belong to the selected thread");
	if (path.basename(candidate) === "package.md") candidate = path.dirname(candidate);
	const direct = await fs.stat(candidate).catch(() => undefined);
	if (direct?.isDirectory()) {
		await validateBundle(candidate);
		const metadata = await packageMetadata(path.join(candidate, "package.md"), path.basename(candidate));
		if (metadata.thread !== thread) throw new Error(`task ownership mismatch: ${metadata.thread} != ${thread}`);
		return metadata;
	}
	for (const name of await fs.readdir(root).catch(() => [])) {
		const bundle = path.join(root, name);
		if (!(await fs.stat(bundle).catch(() => undefined))?.isDirectory()) continue;
		const packagePath = path.join(bundle, "package.md");
		if (!(await fs.stat(packagePath).catch(() => undefined))?.isFile()) continue;
		const metadata = await packageMetadata(packagePath, name);
		if (name === value || metadata.id === value) {
			if (metadata.thread !== thread) throw new Error(`task ownership mismatch: ${metadata.thread} != ${thread}`);
			await validateBundle(bundle);
			return metadata;
		}
	}
	throw new Error(`task not found for thread '${thread}': ${value}`);
}

export async function listTasks(workspacePath: string, thread: string): Promise<TaskRecord[]> {
	if (!validSegment(thread)) throw new Error("task must belong to a directory-safe thread");
	const root = path.resolve(workspacePath, "threads", thread, "tasks");
	const result: TaskRecord[] = [];
	for (const name of await fs.readdir(root).catch(() => [])) {
		const bundle = path.join(root, name);
		if (!(await fs.stat(bundle).catch(() => undefined))?.isDirectory()) continue;
		const packagePath = path.join(bundle, "package.md");
		if (!(await fs.stat(packagePath).catch(() => undefined))?.isFile()) continue;
		await validateBundle(bundle);
		const metadata = await packageMetadata(packagePath, name);
		if (metadata.status === "done" || metadata.status === "failed") continue;
		result.push(metadata);
	}
	return result.sort((a, b) => a.title.localeCompare(b.title) || a.id.localeCompare(b.id));
}

export async function deleteOpenTasks(workspacePath: string, thread: string): Promise<TaskRecord[]> {
	const packages = await listTasks(workspacePath, thread);
	const root = path.resolve(workspacePath, "threads", thread, "tasks");
	const open = packages.filter((pkg) => pkg.status !== "done" && pkg.status !== "failed");
	for (const pkg of open) {
		if (!inside(root, pkg.path)) throw new Error("task must belong to the selected thread");
		await fs.rm(pkg.path, { recursive: true, force: true });
	}
	return open;
}

export async function createTask(workspacePath: string, thread: string, title: string): Promise<TaskRecord> {
	if (!validSegment(thread)) throw new Error("task must belong to a directory-safe thread");
	const cleanTitle = title.trim();
	if (!cleanTitle) throw new Error("usage: /agent-os task spar <title>");
	const root = path.resolve(workspacePath, "threads", thread, "tasks");
	await fs.mkdir(root, { recursive: true });
	const base = slugify(cleanTitle, "task");
	let id = base;
	let packageRoot = path.join(root, id);
	for (let i = 2; (await fs.stat(packageRoot).catch(() => undefined)); i += 1) {
		id = `${base}-${i}`;
		packageRoot = path.join(root, id);
	}
	const packagePath = path.join(packageRoot, "package.md");
	const now = new Date().toISOString();
	await fs.mkdir(packageRoot, { recursive: true });
	await Promise.all(BUNDLE_DIRECTORIES.map((directory) => fs.mkdir(path.join(packageRoot, directory))));
	await writeMarkdownDocument(packagePath, { type: "Task", id, title: cleanTitle, thread, status: "draft", createdAt: now, updatedAt: now, goal: cleanTitle }, `# Goal\n\n${cleanTitle}\n\n## Spar\n\n- Problem:\n- Desired outcome:\n- Constraints:\n- Next decision:\n`);
	return { id, type: "task", title: cleanTitle, thread, status: "draft", createdAt: now, updatedAt: now, path: packageRoot, packagePath, goal: cleanTitle };
}

export async function transitionTask(workspacePath: string, thread: string, input: string, to: TaskStatus): Promise<TaskRecord> {
	const current = await resolveTask(workspacePath, thread, input);
	validateTaskStatus(to);
	if (!canTransitionTask(current.status, to)) throw new Error(`invalid task transition: ${current.status} -> ${to}`);
	const document = parseMarkdownDocument(current.packagePath, await fs.readFile(current.packagePath, "utf8"));
	const now = new Date().toISOString();
	await writeMarkdownDocument(current.packagePath, { ...document.frontmatter, type: "Task", id: current.id, title: current.title, thread: current.thread, status: to, createdAt: current.createdAt, updatedAt: now }, document.body);
	return { ...current, status: to, updatedAt: now };
}

function runReportName(id: string, now: string): string {
	if (!validSegment(id)) throw new Error("task id must be a directory-safe path segment");
	return `${now.slice(0, 10)}-${id}.md`;
}

export async function createRunReport(task: TaskRecord, now = new Date().toISOString()): Promise<string> {
	const reportPath = path.join(task.path, "runs", runReportName(task.id, now));
	await writeMarkdownDocument(reportPath, {
		type: "RunReport",
		id: path.basename(reportPath, ".md"),
		thread: task.thread,
		task: task.id,
		status: "running",
		startedAt: now,
		createdAt: now,
	}, "# Run Report\n\n## Execution\n\n- Status: running\n");
	return reportPath;
}

export async function latestRunReport(task: TaskRecord): Promise<string> {
	const suffix = `-${task.id}.md`;
	const names = (await fs.readdir(path.join(task.path, "runs")).catch(() => []))
		.filter((name) => name.endsWith(suffix))
		.sort()
		.reverse();
	if (!names[0]) throw new Error(`run report not found for task '${task.id}'`);
	return path.join(task.path, "runs", names[0]);
}

export async function latestRunOutcome(task: TaskRecord): Promise<TaskRunOutcome | undefined> {
	const reportPath = await latestRunReport(task).catch(() => undefined);
	if (!reportPath) return undefined;
	const document = parseMarkdownDocument(reportPath, await fs.readFile(reportPath, "utf8"));
	const outcome = document.frontmatter.outcome;
	if (outcome !== "success" && outcome !== "failure") return undefined;
	return {
		outcome,
		completedAt: typeof document.frontmatter.completedAt === "string" ? document.frontmatter.completedAt : undefined,
	};
}

export async function appendRunOutcome(reportPath: string, outcome: RunOutcome, note?: string, now = new Date().toISOString()): Promise<void> {
	if (outcome !== "success" && outcome !== "failure") throw new Error(`invalid run outcome: ${outcome}`);
	const document = parseMarkdownDocument(reportPath, await fs.readFile(reportPath, "utf8").catch(() => ""));
	if (String(document.frontmatter.type ?? "").toLowerCase() !== "runreport") throw new Error(`invalid run report: ${reportPath}`);
	const cleanNote = note?.trim();
	await writeMarkdownDocument(reportPath, {
		...document.frontmatter,
		outcome,
		completedAt: now,
		updatedAt: now,
	}, `${document.body.trimEnd()}\n\n## Outcome\n\n- Result: ${outcome}${cleanNote ? `\n- Note: ${cleanNote}` : ""}\n`);
}

export async function runTask(
	workspacePath: string,
	thread: string,
	input: string,
	launcher?: FactoryRunLauncher,
): Promise<FactoryRun> {
	let current = await resolveTask(workspacePath, thread, input);
	if (current.status === "draft") current = await transitionTask(workspacePath, thread, input, "specced");
	if (current.status !== "specced") throw new Error(`invalid task transition: ${current.status} -> running`);
	current = await transitionTask(workspacePath, thread, input, "running");
	const runReportPath = await createRunReport(current);
	if (launcher) await launcher(current, runReportPath);
	return { task: current, runReportPath };
}

export async function reportTaskRun(
	workspacePath: string,
	thread: string,
	input: string,
	outcome: RunOutcome,
	note?: string,
): Promise<TaskRecord> {
	const current = await resolveTask(workspacePath, thread, input);
	if (current.status !== "running") throw new Error(`invalid task transition: ${current.status} -> review`);
	await appendRunOutcome(await latestRunReport(current), outcome, note);
	return transitionTask(workspacePath, thread, input, "review");
}

export function taskRelativePath(workspacePath: string, taskPath: string): string {
	return path.relative(path.resolve(workspacePath), path.resolve(taskPath));
}
