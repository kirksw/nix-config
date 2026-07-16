/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { parseMarkdownDocument, writeMarkdownDocument } from "./markdown-store.ts";
import type { WorkpackageRecord, WorkpackageStatus } from "./schema.js";
import { slugify } from "./slug.js";

export type { WorkpackageRecord, WorkpackageStatus } from "./schema.js";

export interface WorkpackageBinding {
	id: string;
	path: string;
	packagePath: string;
}

export type FactoryRunLauncher = (workpackage: WorkpackageRecord, runReportPath: string) => Promise<void>;

export interface FactoryRun {
	workpackage: WorkpackageRecord;
	runReportPath: string;
}

export type RunOutcome = "success" | "failure";

export const WORKPACKAGE_STATUSES: readonly WorkpackageStatus[] = ["draft", "specced", "running", "review", "done", "failed"];
export const WORKPACKAGE_TRANSITIONS: Readonly<Record<WorkpackageStatus, readonly WorkpackageStatus[]>> = {
	draft: ["specced"],
	specced: ["running"],
	running: ["review"],
	review: ["done", "failed"],
	done: [],
	failed: [],
};

const BUNDLE_DIRECTORIES = ["input", "runs", "output"] as const;

function inside(root: string, candidate: string): boolean {
	const relative = path.relative(path.resolve(root), path.resolve(candidate));
	return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function validSegment(value: string): boolean {
	return Boolean(value && value !== "." && value !== ".." && !value.includes("/") && !value.includes("\\"));
}

function validStatus(value: unknown): value is WorkpackageStatus {
	return typeof value === "string" && (WORKPACKAGE_STATUSES as readonly string[]).includes(value);
}

function validTimestamp(value: unknown): value is string {
	return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

export function validateWorkpackageStatus(value: unknown): asserts value is WorkpackageStatus {
	if (!validStatus(value)) throw new Error(`invalid workpackage status: ${String(value)}`);
}

export function canTransitionWorkpackage(from: WorkpackageStatus, to: WorkpackageStatus): boolean {
	validateWorkpackageStatus(from);
	validateWorkpackageStatus(to);
	return WORKPACKAGE_TRANSITIONS[from].includes(to);
}

async function validateBundle(root: string): Promise<void> {
	const stat = await fs.stat(root).catch(() => undefined);
	if (!stat?.isDirectory()) throw new Error(`workpackage bundle not found: ${root}`);
	const packageStat = await fs.stat(path.join(root, "package.md")).catch(() => undefined);
	if (!packageStat?.isFile()) throw new Error(`non-canonical workpackage bundle (package.md is not a file): ${root}`);
	const entries = await fs.readdir(root);
	for (const required of ["package.md", ...BUNDLE_DIRECTORIES]) {
		if (!entries.includes(required)) throw new Error(`non-canonical workpackage bundle (missing ${required}): ${root}`);
	}
	for (const entry of entries) {
		if (entry !== "package.md" && !(BUNDLE_DIRECTORIES as readonly string[]).includes(entry)) {
			throw new Error(`non-canonical workpackage bundle (unexpected ${entry}): ${root}`);
		}
	}
	for (const directory of BUNDLE_DIRECTORIES) {
		if (!(await fs.stat(path.join(root, directory)).catch(() => undefined))?.isDirectory()) {
			throw new Error(`non-canonical workpackage bundle (${directory} is not a directory): ${root}`);
		}
	}
}

async function packageMetadata(packagePath: string, fallback: string): Promise<WorkpackageRecord> {
	const document = parseMarkdownDocument(packagePath, await fs.readFile(packagePath, "utf8").catch(() => ""));
	const fm = document.frontmatter;
	const bundle = path.dirname(packagePath);
	if (String(fm.type ?? "").toLowerCase() !== "workpackage") throw new Error(`invalid workpackage type: ${bundle}`);
	if (typeof fm.id !== "string" || !fm.id) throw new Error(`workpackage id is required: ${bundle}`);
	if (typeof fm.title !== "string" || !fm.title) throw new Error(`workpackage title is required: ${bundle}`);
	if (typeof fm.thread !== "string" || !fm.thread) throw new Error(`workpackage thread is required: ${bundle}`);
	if (typeof fm.status !== "string") throw new Error(`workpackage status is required: ${bundle}`);
	const id = fm.id;
	const title = fm.title;
	const status = fm.status;
	validateWorkpackageStatus(status);
	const created = fm.createdAt ?? fm.timestamp;
	if (!validTimestamp(created)) throw new Error(`workpackage createdAt is required: ${bundle}`);
	if (fm.updatedAt !== undefined && !validTimestamp(fm.updatedAt)) throw new Error(`workpackage updatedAt is invalid: ${bundle}`);
	return {
		id,
		type: "workpackage",
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

export async function resolveWorkpackage(workspacePath: string, thread: string, input: string): Promise<WorkpackageRecord> {
	if (!validSegment(thread)) throw new Error("workpackage must belong to a directory-safe thread");
	const root = path.resolve(workspacePath, "threads", thread, "workpackages");
	const value = input.trim();
	if (!value) throw new Error("usage: /agent-os workpackage <id|path|clear>");
	if (value === "clear") throw new Error("clear is not a workpackage");
	const workspaceRelative = `threads/${thread}/workpackages/`;
	let candidate = path.resolve(path.isAbsolute(value) ? value : value.startsWith(workspaceRelative) ? path.join(workspacePath, value) : path.join(root, value));
	if (!inside(root, candidate)) throw new Error("workpackage must belong to the selected thread");
	if (path.basename(candidate) === "package.md") candidate = path.dirname(candidate);
	const direct = await fs.stat(candidate).catch(() => undefined);
	if (direct?.isDirectory()) {
		await validateBundle(candidate);
		const metadata = await packageMetadata(path.join(candidate, "package.md"), path.basename(candidate));
		if (metadata.thread !== thread) throw new Error(`workpackage ownership mismatch: ${metadata.thread} != ${thread}`);
		return metadata;
	}
	for (const name of await fs.readdir(root).catch(() => [])) {
		const bundle = path.join(root, name);
		if (!(await fs.stat(bundle).catch(() => undefined))?.isDirectory()) continue;
		const packagePath = path.join(bundle, "package.md");
		if (!(await fs.stat(packagePath).catch(() => undefined))?.isFile()) continue;
		const metadata = await packageMetadata(packagePath, name);
		if (name === value || metadata.id === value) {
			if (metadata.thread !== thread) throw new Error(`workpackage ownership mismatch: ${metadata.thread} != ${thread}`);
			await validateBundle(bundle);
			return metadata;
		}
	}
	throw new Error(`workpackage not found for thread '${thread}': ${value}`);
}

export async function listWorkpackages(workspacePath: string, thread: string): Promise<WorkpackageRecord[]> {
	if (!validSegment(thread)) throw new Error("workpackage must belong to a directory-safe thread");
	const root = path.resolve(workspacePath, "threads", thread, "workpackages");
	const result: WorkpackageRecord[] = [];
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

export async function deleteOpenWorkpackages(workspacePath: string, thread: string): Promise<WorkpackageRecord[]> {
	const packages = await listWorkpackages(workspacePath, thread);
	const root = path.resolve(workspacePath, "threads", thread, "workpackages");
	const open = packages.filter((pkg) => pkg.status !== "done" && pkg.status !== "failed");
	for (const pkg of open) {
		if (!inside(root, pkg.path)) throw new Error("workpackage must belong to the selected thread");
		await fs.rm(pkg.path, { recursive: true, force: true });
	}
	return open;
}

export async function createWorkpackage(workspacePath: string, thread: string, title: string): Promise<WorkpackageRecord> {
	if (!validSegment(thread)) throw new Error("workpackage must belong to a directory-safe thread");
	const cleanTitle = title.trim();
	if (!cleanTitle) throw new Error("usage: /agent-os wp spar <title>");
	const root = path.resolve(workspacePath, "threads", thread, "workpackages");
	await fs.mkdir(root, { recursive: true });
	const base = slugify(cleanTitle, "workpackage");
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
	await writeMarkdownDocument(packagePath, { type: "Workpackage", id, title: cleanTitle, thread, status: "draft", createdAt: now, updatedAt: now, goal: cleanTitle }, `# Goal\n\n${cleanTitle}\n\n## Spar\n\n- Problem:\n- Desired outcome:\n- Constraints:\n- Next decision:\n`);
	return { id, type: "workpackage", title: cleanTitle, thread, status: "draft", createdAt: now, updatedAt: now, path: packageRoot, packagePath, goal: cleanTitle };
}

export async function transitionWorkpackage(workspacePath: string, thread: string, input: string, to: WorkpackageStatus): Promise<WorkpackageRecord> {
	const current = await resolveWorkpackage(workspacePath, thread, input);
	validateWorkpackageStatus(to);
	if (!canTransitionWorkpackage(current.status, to)) throw new Error(`invalid workpackage transition: ${current.status} -> ${to}`);
	const document = parseMarkdownDocument(current.packagePath, await fs.readFile(current.packagePath, "utf8"));
	const now = new Date().toISOString();
	await writeMarkdownDocument(current.packagePath, { ...document.frontmatter, type: "Workpackage", id: current.id, title: current.title, thread: current.thread, status: to, createdAt: current.createdAt, updatedAt: now }, document.body);
	return { ...current, status: to, updatedAt: now };
}

function runReportName(id: string, now: string): string {
	if (!validSegment(id)) throw new Error("workpackage id must be a directory-safe path segment");
	return `${now.slice(0, 10)}-${id}.md`;
}

export async function createRunReport(workpackage: WorkpackageRecord, now = new Date().toISOString()): Promise<string> {
	const reportPath = path.join(workpackage.path, "runs", runReportName(workpackage.id, now));
	await writeMarkdownDocument(reportPath, {
		type: "RunReport",
		id: path.basename(reportPath, ".md"),
		thread: workpackage.thread,
		workpackage: workpackage.id,
		status: "running",
		startedAt: now,
		createdAt: now,
	}, "# Run Report\n\n## Execution\n\n- Status: running\n");
	return reportPath;
}

export async function latestRunReport(workpackage: WorkpackageRecord): Promise<string> {
	const suffix = `-${workpackage.id}.md`;
	const names = (await fs.readdir(path.join(workpackage.path, "runs")).catch(() => []))
		.filter((name) => name.endsWith(suffix))
		.sort()
		.reverse();
	if (!names[0]) throw new Error(`run report not found for workpackage '${workpackage.id}'`);
	return path.join(workpackage.path, "runs", names[0]);
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

export async function runWorkpackage(
	workspacePath: string,
	thread: string,
	input: string,
	launcher?: FactoryRunLauncher,
): Promise<FactoryRun> {
	let current = await resolveWorkpackage(workspacePath, thread, input);
	if (current.status === "draft") current = await transitionWorkpackage(workspacePath, thread, input, "specced");
	if (current.status !== "specced") throw new Error(`invalid workpackage transition: ${current.status} -> running`);
	current = await transitionWorkpackage(workspacePath, thread, input, "running");
	const runReportPath = await createRunReport(current);
	if (launcher) await launcher(current, runReportPath);
	return { workpackage: current, runReportPath };
}

export async function reportWorkpackageRun(
	workspacePath: string,
	thread: string,
	input: string,
	outcome: RunOutcome,
	note?: string,
): Promise<WorkpackageRecord> {
	const current = await resolveWorkpackage(workspacePath, thread, input);
	if (current.status !== "running") throw new Error(`invalid workpackage transition: ${current.status} -> review`);
	await appendRunOutcome(await latestRunReport(current), outcome, note);
	return transitionWorkpackage(workspacePath, thread, input, "review");
}

export function workpackageRelativePath(workspacePath: string, workpackagePath: string): string {
	return path.relative(path.resolve(workspacePath), path.resolve(workpackagePath));
}
