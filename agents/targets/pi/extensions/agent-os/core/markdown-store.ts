/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type {
	BlockerRecord,
	CandidateRecord,
	DecisionRecord,
	LifeOsData,
	KnowledgeBaseReference,
	MetricRecord,
	OutcomeRecord,
	ThreadRecord,
	ThreadLinear,
	TaskRecord,
	TaskStatus,
} from "./schema.ts";

export interface MarkdownDocument {
	file: string;
	frontmatter: Record<string, unknown>;
	body: string;
}

function scalar(value: string): unknown {
	const trimmed = value.trim();
	if (!trimmed) return "";
	try {
		if (trimmed.startsWith("{") || trimmed.startsWith("[") || trimmed.startsWith('"')) {
			return JSON.parse(trimmed);
		}
	} catch {
		// Keep migration input readable as a string.
	}
	if (trimmed.startsWith("'") && trimmed.endsWith("'")) return trimmed.slice(1, -1).replace(/''/g, "'");
	if (trimmed === "null") return undefined;
	if (trimmed === "true") return true;
	if (trimmed === "false") return false;
	if (/^-?\d+(\.\d+)?$/.test(trimmed)) return Number(trimmed);
	return trimmed;
}

/** Parse the deliberately JSON-compatible structured frontmatter representation. */
export function parseMarkdownDocument(file: string, text: string): MarkdownDocument {
	if (!text.startsWith("---\n") && !text.startsWith("---\r\n")) {
		return { file, frontmatter: {}, body: text };
	}
	const match = text.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
	if (!match) return { file, frontmatter: {}, body: text };
	const frontmatter: Record<string, unknown> = {};
	for (const line of match[1].split(/\r?\n/)) {
		const item = line.match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$/);
		if (item) frontmatter[item[1]] = scalar(item[2]);
	}
	return { file, frontmatter, body: text.slice(match[0].length) };
}

async function readDocument(file: string): Promise<MarkdownDocument> {
	return parseMarkdownDocument(file, await fs.readFile(file, "utf8"));
}

async function filesIn(root: string): Promise<string[]> {
	const result: string[] = [];
	for (const name of await fs.readdir(root).catch(() => [])) {
		const file = path.join(root, name);
		const stat = await fs.stat(file).catch(() => undefined);
		if (!stat) continue;
		if (stat.isDirectory()) result.push(...(await filesIn(file)));
		else if (stat.isFile() && name.endsWith(".md")) result.push(file);
	}
	return result;
}

function textValue(frontmatter: Record<string, unknown>, body: string): string {
	const value = frontmatter.text ?? frontmatter.title;
	if (typeof value === "string" && value.trim()) return value.trim();
	return body.replace(/^\s*#.*\n+/, "").trim();
}

function firstH1(body: string): string | undefined {
	const match = body.match(/^\s*#\s+(.+?)(?:\s+#+)?\s*$/m);
	return match?.[1].trim() || undefined;
}

function createdAt(frontmatter: Record<string, unknown>): string {
	const value = frontmatter.createdAt ?? frontmatter.created ?? frontmatter.timestamp;
	return typeof value === "string" ? value : new Date(0).toISOString();
}

function updatedAt(frontmatter: Record<string, unknown>): string | undefined {
	const value = frontmatter.updatedAt ?? frontmatter.updated;
	return typeof value === "string" ? value : undefined;
}

function isIsoTimestamp(value: unknown): value is string {
	return typeof value === "string" && !Number.isNaN(Date.parse(value));
}

async function resolveCreatedAt(frontmatter: Record<string, unknown>, file: string): Promise<string> {
	const value = frontmatter.createdAt ?? frontmatter.timestamp;
	if (isIsoTimestamp(value)) return value;
	const stat = await fs.stat(file).catch(() => undefined);
	if (stat) return stat.mtime.toISOString();
	throw new Error(`createdAt cannot be derived for ${file}`);
}

function assertThreadOwner(frontmatter: Record<string, unknown>, owner: string, file: string): void {
	const thread = recordThread(frontmatter, "");
	if (thread && thread !== owner) throw new Error(`thread ownership mismatch for ${file}: ${thread} != ${owner}`);
}

function recordBase(frontmatter: Record<string, unknown>, id: string) {
	return { id, createdAt: createdAt(frontmatter), ...(updatedAt(frontmatter) ? { updatedAt: updatedAt(frontmatter) } : {}) };
}

function threadId(slug: string): string {
	return `thread:${slug}`;
}

function recordThread(frontmatter: Record<string, unknown>, fallback: string): string | undefined {
	const value = frontmatter.thread ?? frontmatter.threadId;
	if (typeof value === "string" && value) return value.replace(/^thread:/, "");
	return fallback || undefined;
}

function threadFields(frontmatter: Record<string, unknown>): Pick<ThreadRecord, "linear" | "kbs" | "repos"> {
	const linear = frontmatter.linear;
	const linearValue: ThreadLinear | undefined = typeof linear === "object" && linear !== null && !Array.isArray(linear)
		? {
			initiatives: Array.isArray((linear as Record<string, unknown>).initiatives) ? (linear as Record<string, unknown>).initiatives.filter((v): v is string => typeof v === "string") : [],
			projects: Array.isArray((linear as Record<string, unknown>).projects) ? (linear as Record<string, unknown>).projects.filter((v): v is string => typeof v === "string") : [],
		}
		: undefined;
	const kbs = Array.isArray(frontmatter.kbs)
		? frontmatter.kbs.flatMap((value): KnowledgeBaseReference[] => {
			if (typeof value !== "object" || value === null || Array.isArray(value)) return [];
			const item = value as Record<string, unknown>;
			if (typeof item.id !== "string" || typeof item.scope !== "string") return [];
			return [{ id: item.id, scope: item.scope, ...(typeof item.note === "string" ? { note: item.note } : {}) }];
		})
		: undefined;
	const repos = Array.isArray(frontmatter.repos) ? frontmatter.repos.filter((v): v is string => typeof v === "string") : undefined;
	return { linear: linearValue, kbs, repos };
}

export async function readMarkdownThreads(workspacePath: string): Promise<ThreadRecord[]> {
	const root = path.join(workspacePath, "threads");
	const threads: ThreadRecord[] = [];
	for (const slug of await fs.readdir(root).catch(() => [])) {
		const directory = path.join(root, slug);
		const stat = await fs.stat(directory).catch(() => undefined);
		if (!stat?.isDirectory()) continue;
		const file = path.join(directory, "README.md");
		const document = await readDocument(file).catch(() => undefined);
		if (!document || String(document.frontmatter.type ?? "").toLowerCase() !== "thread") continue;
		const fm = document.frontmatter;
		const fileStat = await fs.stat(file).catch(() => undefined);
		if (!fileStat) continue;
		const actualSlug = slug;
		if (typeof fm.slug === "string" && fm.slug !== actualSlug) {
			console.warn(`thread slug '${fm.slug}' does not match directory '${actualSlug}'`);
		}
		const id = typeof fm.id === "string" && fm.id.trim() ? fm.id : threadId(actualSlug);
		const existingCreatedAt = fm.createdAt ?? fm.created ?? fm.timestamp;
		const createdAt = typeof existingCreatedAt === "string" && existingCreatedAt.trim()
			? existingCreatedAt
			: fileStat.mtime.toISOString();
		const title = typeof fm.title === "string" && fm.title.trim()
			? fm.title.trim()
			: firstH1(document.body) ?? actualSlug;
		if (fm.updatedAt !== undefined && !isIsoTimestamp(fm.updatedAt)) throw new Error(`updatedAt is invalid for ${file}`);
		threads.push({
			...recordBase({ ...fm, createdAt }, id),
			type: "thread",
			slug: actualSlug,
			title,
			kind: typeof fm.kind === "string" ? fm.kind : "project",
			status: typeof fm.status === "string" ? fm.status : "active",
			stage: typeof fm.stage === "string" ? fm.stage : "unspecified",
			path: path.join("threads", slug),
			...threadFields(fm),
			salience: typeof fm.salience === "number" ? fm.salience : undefined,
			impact: typeof fm.impact === "number" ? fm.impact : undefined,
			confidence: typeof fm.confidence === "number" ? fm.confidence : undefined,
			urgency: typeof fm.urgency === "number" ? fm.urgency : undefined,
			effort: typeof fm.effort === "number" ? fm.effort : undefined,
			manualOverride: typeof fm.manualOverride === "number" ? fm.manualOverride : undefined,
		});
	}
	return threads.sort((a, b) => a.title.localeCompare(b.title) || a.slug.localeCompare(b.slug));
}

function canonicalRecordPath(workspacePath: string, file: string, kind: string): { thread?: string } | undefined {
	const relative = path.relative(workspacePath, file).split(path.sep);
	if (relative.length === 3 && relative[0] === "inbox" && relative[1] === kind && relative[2].endsWith(".md")) return {};
	if (relative.length === 4 && relative[0] === "threads" && relative[2] === kind && relative[3].endsWith(".md")) return { thread: relative[1] };
	return undefined;
}

async function readMarkdownRecords(workspacePath: string, kind: "decisions" | "blockers" | "candidates"): Promise<Array<DecisionRecord | BlockerRecord | CandidateRecord>> {
	const records: Array<DecisionRecord | BlockerRecord | CandidateRecord> = [];
	for (const file of await filesIn(workspacePath)) {
		const location = canonicalRecordPath(workspacePath, file, kind);
		if (!location) continue;
		const document = await readDocument(file);
		const fm = document.frontmatter;
		const type = String(fm.type ?? "").toLowerCase();
		if (type !== kind.slice(0, -1)) continue;
		if (location.thread) assertThreadOwner(fm, location.thread, file);
		if (typeof fm.id !== "string" || !fm.id) throw new Error(`record id is required: ${file}`);
		const resolvedCreatedAt = await resolveCreatedAt(fm, file);
		if (fm.updatedAt !== undefined && !isIsoTimestamp(fm.updatedAt)) throw new Error(`updatedAt is invalid for ${file}`);
		const thread = recordThread(fm, location.thread ?? "");
		if (kind !== "blockers" && fm.source !== "pi") continue;
		const id = typeof fm.id === "string" ? fm.id : `${kind.slice(0, -1)}:${path.basename(file, ".md")}`;
		const base = recordBase({ ...fm, createdAt: resolvedCreatedAt }, id);
		if (kind === "decisions") {
			records.push({ ...base, type: "decision", text: textValue(fm, document.body), source: "pi", threadId: thread ? threadId(thread) : undefined });
		} else if (kind === "blockers") {
			if (fm.status !== "open" && fm.status !== "resolved") continue;
			records.push({ ...base, type: "blocker", text: textValue(fm, document.body), status: fm.status === "resolved" ? "resolved" : "open", threadId: thread ? threadId(thread) : undefined });
		} else {
			if (fm.status !== "review" && fm.status !== "promoted" && fm.status !== "rejected") continue;
			records.push({ ...base, type: "candidate", text: textValue(fm, document.body), source: "pi", status: fm.status === "promoted" || fm.status === "rejected" ? fm.status : "review", threadId: thread ? threadId(thread) : undefined, reason: typeof fm.reason === "string" ? fm.reason : undefined });
		}
	}
	return records;
}

async function readMarkdownMetrics(workspacePath: string): Promise<MetricRecord[]> {
	const metrics: MetricRecord[] = [];
	for (const file of await filesIn(workspacePath)) {
		const relative = path.relative(workspacePath, file).split(path.sep);
		if (relative.length !== 5 || relative[0] !== "threads" || relative[2] !== "artifacts" || relative[3] !== "metrics") continue;
		const document = await readDocument(file);
		const fm = document.frontmatter;
		if (String(fm.type ?? "").toLowerCase() !== "metric") continue;
		assertThreadOwner(fm, relative[1], file);
		if (typeof fm.id !== "string" || !fm.id || typeof fm.name !== "string" || typeof fm.kind !== "string") throw new Error(`invalid Metric frontmatter: ${file}`);
		const resolvedCreatedAt = await resolveCreatedAt(fm, file);
		if (fm.updatedAt !== undefined && !isIsoTimestamp(fm.updatedAt)) throw new Error(`updatedAt is invalid for ${file}`);
		const id = fm.id;
		if (!["quantitative", "qualitative", "milestone", "capability"].includes(fm.kind)) throw new Error(`invalid Metric kind: ${file}`);
		const kind = fm.kind as MetricRecord["kind"];
		metrics.push({ ...recordBase({ ...fm, createdAt: resolvedCreatedAt }, id), type: "metric", thread: recordThread(fm, relative[1]), name: typeof fm.name === "string" ? fm.name : textValue(fm, document.body), kind, target: typeof fm.target === "string" ? fm.target : undefined, current: typeof fm.current === "string" ? fm.current : undefined });
	}
	return metrics;
}

export async function readMarkdownOutcomes(workspacePath: string): Promise<OutcomeRecord[]> {
	const outcomes: OutcomeRecord[] = [];
	for (const file of await filesIn(path.join(workspacePath, "outcomes"))) {
		if (path.dirname(file) !== path.join(workspacePath, "outcomes")) continue;
		const document = await readDocument(file);
		const fm = document.frontmatter;
		if (String(fm.type ?? "").toLowerCase() !== "outcome") continue;
		const state = fm.state;
		if (typeof fm.id !== "string" || typeof fm.title !== "string" || typeof fm.goal !== "string" || typeof state !== "string" || !["planned", "in_progress", "done", "blocked", "archived"].includes(state)) continue;
		const resolvedCreatedAt = await resolveCreatedAt(fm, file);
		if (fm.updatedAt !== undefined && !isIsoTimestamp(fm.updatedAt)) throw new Error(`updatedAt is invalid for ${file}`);
		outcomes.push({ ...recordBase({ ...fm, createdAt: resolvedCreatedAt }, fm.id), type: "outcome", title: fm.title, ...(typeof fm.thread === "string" ? { thread: fm.thread } : {}), ...(typeof fm.task === "string" ? { task: fm.task } : {}), goal: fm.goal, ...(typeof fm.result === "string" ? { result: fm.result } : {}), state: state as OutcomeRecord["state"], ...(typeof fm.closedAt === "string" ? { closedAt: fm.closedAt } : {}) });
	}
	return outcomes;
}

export async function readMarkdownTasks(workspacePath: string): Promise<TaskRecord[]> {
	const result: TaskRecord[] = [];
	for (const thread of await fs.readdir(path.join(workspacePath, "threads")).catch(() => [])) {
		const root = path.join(workspacePath, "threads", thread, "tasks");
		for (const bundleId of await fs.readdir(root).catch(() => [])) {
			const bundle = path.join(root, bundleId);
			const stat = await fs.stat(bundle).catch(() => undefined);
			if (!stat?.isDirectory()) continue;
			const packagePath = path.join(bundle, "package.md");
			if (!(await fs.stat(packagePath).catch(() => undefined))?.isFile()) continue;
			const entries = await fs.readdir(bundle);
			const expected = ["package.md", "input", "runs", "artifacts"];
			if (entries.some((entry) => !expected.includes(entry)) || expected.some((entry) => !entries.includes(entry))) throw new Error(`non-canonical task bundle: ${bundle}`);
			for (const directory of ["input", "runs", "artifacts"]) {
				if (!(await fs.stat(path.join(bundle, directory)).catch(() => undefined))?.isDirectory()) throw new Error(`non-canonical task bundle: ${bundle}`);
			}
			const document = await readDocument(packagePath);
			const fm = document.frontmatter;
			if (String(fm.type ?? "").toLowerCase() !== "task") continue;
			const id = typeof fm.id === "string" && fm.id.trim() ? fm.id.trim() : bundleId;
			const title = typeof fm.title === "string" && fm.title.trim() ? fm.title.trim() : firstH1(document.body) ?? id;
			const physicalThread = typeof fm.thread === "string" && fm.thread.trim() ? fm.thread.trim() : thread;
			const status = typeof fm.status === "string" && ["draft", "specced", "running", "review", "done", "failed"].includes(fm.status) ? fm.status : "draft";
			if (physicalThread !== thread) throw new Error(`task ownership mismatch for ${packagePath}: ${physicalThread} != ${thread}`);
			const resolvedCreatedAt = await resolveCreatedAt(fm, packagePath);
			result.push({ ...recordBase({ ...fm, createdAt: resolvedCreatedAt }, id), type: "task", title, thread: physicalThread, status: status as TaskStatus, path: bundle, packagePath, goal: typeof fm.goal === "string" ? fm.goal : undefined, notes: typeof fm.notes === "string" ? fm.notes : undefined });
		}
	}
	return result;
}

export async function readMarkdownData(workspacePath: string): Promise<LifeOsData> {
	const [threads, decisions, blockers, candidates, metrics, outcomes, tasks] = await Promise.all([
		readMarkdownThreads(workspacePath),
		readMarkdownRecords(workspacePath, "decisions"),
		readMarkdownRecords(workspacePath, "blockers"),
		readMarkdownRecords(workspacePath, "candidates"),
		readMarkdownMetrics(workspacePath),
		readMarkdownOutcomes(workspacePath),
		readMarkdownTasks(workspacePath),
	]);
	return { threads, tasks, outcomes, decisions: decisions as DecisionRecord[], blockers: blockers as BlockerRecord[], candidates: candidates as CandidateRecord[], metrics, edges: [] };
}

function quote(value: string): string {
	return JSON.stringify(value);
}

function frontmatter(fields: Record<string, unknown>): string {
	return ["---", ...Object.entries(fields).map(([key, value]) => {
		if (typeof value === "string") return `${key}: ${key === "type" ? value : quote(value)}`;
		if (value === undefined) return undefined;
		return `${key}: ${JSON.stringify(value)}`;
	}).filter((line): line is string => Boolean(line)), "---", ""].join("\n");
}

export async function writeMarkdownDocument(file: string, fields: Record<string, unknown>, body: string): Promise<void> {
	await fs.mkdir(path.dirname(file), { recursive: true });
	const temporary = `${file}.tmp-${process.pid}-${Date.now()}`;
	await fs.writeFile(temporary, `${frontmatter(fields)}\n${body.replace(/^\n+/, "")}`, "utf8");
	await fs.rename(temporary, file);
}

const THREAD_DIRECTORIES = ["plans", "research", "artifacts", "decisions", "blockers", "candidates", "sessions", "tasks"];

export async function writeThreadDocument(workspacePath: string, thread: ThreadRecord): Promise<string> {
	if (!thread.slug || thread.slug.includes("/") || thread.slug.includes("\\")) throw new Error("thread slug must be directory-safe");
	const root = path.join(workspacePath, "threads", thread.slug);
	const file = path.join(root, "README.md");
	await fs.mkdir(root, { recursive: true });
	await Promise.all(THREAD_DIRECTORIES.map((directory) => fs.mkdir(path.join(root, directory), { recursive: true })));
	await writeMarkdownDocument(file, {
		type: "Thread",
		id: thread.id,
		slug: thread.slug,
		title: thread.title,
		kind: thread.kind,
		status: thread.status,
		stage: thread.stage,
		createdAt: thread.createdAt,
		updatedAt: thread.updatedAt,
		linear: thread.linear ?? { initiatives: [], projects: [] },
		kbs: thread.kbs ?? [],
		repos: thread.repos ?? [],
		salience: thread.salience,
		impact: thread.impact,
		confidence: thread.confidence,
		urgency: thread.urgency,
		effort: thread.effort,
		manualOverride: thread.manualOverride,
	}, `# ${thread.title}\n\n<!-- agent-os:generated:start -->\n_Generated Agent OS state will appear here._\n<!-- agent-os:generated:end -->\n\n## Manual notes\n`);
	return file;
}

function recordId(id: string): void {
	if (!id || id.includes("/") || id.includes("\\") || id === "." || id === "..") throw new Error("record id must be a single path segment");
}

export async function writeMarkdownRecord(workspacePath: string, threadSlug: string | undefined, kind: "decision" | "candidate", id: string, text: string, reason?: string): Promise<string> {
	recordId(id);
	const root = threadSlug ? path.join(workspacePath, "threads", threadSlug, `${kind}s`) : path.join(workspacePath, "inbox", `${kind}s`);
	const file = path.join(root, `${id}.md`);
	const now = new Date().toISOString();
	await writeMarkdownDocument(file, {
		type: kind[0].toUpperCase() + kind.slice(1), id,
		...(threadSlug ? { thread: threadSlug } : {}), source: "pi",
		...(kind === "candidate" ? { status: "review" } : {}),
		...(reason ? { reason } : {}), createdAt: now,
	}, `# ${kind[0].toUpperCase() + kind.slice(1)}\n\n${text}\n`);
	return file;
}

export async function writeBlockerDocument(workspacePath: string, threadSlug: string | undefined, blocker: BlockerRecord): Promise<string> {
	recordId(blocker.id);
	if (threadSlug && (threadSlug.includes("/") || threadSlug.includes("\\") || threadSlug === "." || threadSlug === "..")) {
		throw new Error("thread slug must be a directory-safe path segment");
	}
	if (!blocker.text.trim()) throw new Error("blocker text is required");
	if (blocker.status !== "open" && blocker.status !== "resolved") throw new Error(`invalid blocker status: ${blocker.status}`);
	const root = threadSlug ? path.join(workspacePath, "threads", threadSlug, "blockers") : path.join(workspacePath, "inbox", "blockers");
	const file = path.join(root, `${blocker.id}.md`);
	await writeMarkdownDocument(file, { type: "Blocker", id: blocker.id, ...(threadSlug ? { thread: threadSlug } : {}), status: blocker.status, createdAt: blocker.createdAt, updatedAt: blocker.updatedAt }, `# Blocker\n\n${blocker.text}\n`);
	return file;
}

export async function writeOutcomeDocument(workspacePath: string, outcome: OutcomeRecord): Promise<string> {
	recordId(outcome.id);
	if (!outcome.title.trim() || !outcome.goal.trim()) throw new Error("outcome title and goal are required");
	if (!["planned", "in_progress", "done", "blocked", "archived"].includes(outcome.state)) throw new Error(`invalid outcome state: ${outcome.state}`);
	const file = path.join(workspacePath, "outcomes", `${outcome.id}.md`);
	await writeMarkdownDocument(file, { type: "Outcome", id: outcome.id, title: outcome.title, ...(outcome.thread ? { thread: outcome.thread } : {}), ...(outcome.task ? { task: outcome.task } : {}), goal: outcome.goal, result: outcome.result, state: outcome.state, createdAt: outcome.createdAt, updatedAt: outcome.updatedAt, closedAt: outcome.closedAt }, `# ${outcome.title}\n\n${outcome.result ?? outcome.goal}\n`);
	return file;
}

export async function writeMetricDocument(workspacePath: string, threadSlug: string, metric: MetricRecord): Promise<string> {
	recordId(metric.id);
	if (!threadSlug || threadSlug.includes("/") || threadSlug.includes("\\")) throw new Error("thread slug must be a directory-safe path segment");
	const file = path.join(workspacePath, "threads", threadSlug, "artifacts", "metrics", `${metric.id}.md`);
	await writeMarkdownDocument(file, { type: "Metric", id: metric.id, name: metric.name, kind: metric.kind, thread: threadSlug, target: metric.target, current: metric.current, createdAt: metric.createdAt, updatedAt: metric.updatedAt }, `# ${metric.name}\n`);
	return file;
}

export async function updateMarkdownThread(file: string, updates: Record<string, string>): Promise<void> {
	const text = await fs.readFile(file, "utf8");
	const match = text.match(/^(---\r?\n)([\s\S]*?)(\r?\n---\r?\n?)/);
	if (!match) return;
	const lines = match[2].split(/\r?\n/);
	for (const [key, value] of Object.entries(updates)) {
		const index = lines.findIndex((line) => line.startsWith(`${key}:`));
		if (index >= 0) lines[index] = `${key}: ${quote(value)}`;
		else lines.push(`${key}: ${quote(value)}`);
	}
	const next = `${match[1]}${lines.join("\n")}${match[3]}${text.slice(match[0].length)}`;
	const temporary = `${file}.tmp-${process.pid}-${Date.now()}`;
	await fs.writeFile(temporary, next, "utf8");
	await fs.rename(temporary, file);
}
