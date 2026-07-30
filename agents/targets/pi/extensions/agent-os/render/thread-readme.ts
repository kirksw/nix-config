/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type {
	BlockerRecord,
	DecisionRecord,
	ThreadRecord,
	TaskRecord,
} from "../core/schema.ts";
import { latestRunOutcome, type TaskRunOutcome } from "../core/task.ts";
import type { RenderResult } from "./markdown.ts";
import { writeGeneratedSection, yamlString } from "./markdown.ts";

export async function latestTaskOutcomes(
	tasks: TaskRecord[],
): Promise<ReadonlyMap<string, TaskRunOutcome>> {
	const entries = await Promise.all(tasks.map(async (task) => [
		task.id,
		await latestRunOutcome(task),
	] as const));
	return new Map(entries.filter((entry): entry is [string, TaskRunOutcome] => Boolean(entry[1])));
}

export function threadReadmeFallback(thread: ThreadRecord): string {
	return [
		"---",
		"type: Thread",
		`title: ${yamlString(thread.title)}`,
		`kind: ${yamlString(thread.kind)}`,
		`status: ${yamlString(thread.status)}`,
		`stage: ${yamlString(thread.stage)}`,
		`timestamp: ${yamlString(thread.createdAt)}`,
		"---",
		"",
		`# ${thread.title}`,
		"",
		"<!-- agent-os:generated:start -->",
		"_Generated Agent OS state will appear here._",
		"<!-- agent-os:generated:end -->",
		"",
		"## Manual notes",
		"",
	].join("\n");
}

export function threadGeneratedSection(
	thread: ThreadRecord,
	blockers: BlockerRecord[],
	decisions: DecisionRecord[],
	tasks: TaskRecord[] = [],
	activeTaskPath?: string,
	runOutcomes: ReadonlyMap<string, TaskRunOutcome> = new Map(),
): string {
	const openBlockers = blockers.filter(
		(b) => (b.threadId === thread.id || b.threadId === thread.slug) && b.status !== "resolved",
	);
	const threadDecisions = decisions
		.filter((d) => d.threadId === thread.id || d.threadId === thread.slug)
		.slice(-5)
		.reverse();
	const threadTasks = tasks.filter((task) => task.thread === thread.slug);
	const active = activeTaskPath
		? threadTasks.find((task) => path.resolve(task.path) === path.resolve(activeTaskPath))
		: undefined;
	return [
		"## Agent OS state",
		"",
		`- Status: ${thread.status}`,
		`- Stage: ${thread.stage}`,
		`- Kind: ${thread.kind}`,
		`- Updated: ${thread.updatedAt ?? thread.createdAt}`,
		"",
		"### Tasks",
		"",
		`- Active task: ${active?.id ?? "None"}`,
		...(threadTasks.length === 0
			? ["- None"]
			: threadTasks.map((task) => {
				const outcome = runOutcomes.get(task.id);
				return `- ${task.id}: ${task.status} — ${task.title} (last run: ${outcome?.outcome ?? "none"})`;
			})),
		"",
		"### Open blockers",
		"",
		...(openBlockers.length === 0
			? ["- None"]
			: openBlockers.map((b) => `- ${b.text}`)),
		"",
		"### Recent decisions",
		"",
		...(threadDecisions.length === 0
			? ["- None"]
			: threadDecisions.map((d) => `- ${d.createdAt}: ${d.text}`)),
	].join("\n");
}

function safeThreadReadmePath(
	workspacePath: string,
	thread: ThreadRecord,
): string {
	const workspace = path.resolve(workspacePath);
	const readme = path.resolve(workspace, thread.path, "README.md");
	const relative = path.relative(workspace, readme);
	if (relative.startsWith("..") || path.resolve(readme) === workspace) {
		throw new Error(`unsafe thread path for ${thread.slug}: ${thread.path}`);
	}
	if (!relative.startsWith(`threads${path.sep}`)) {
		throw new Error(`thread path must stay under threads/: ${thread.path}`);
	}
	return readme;
}

export async function renderThreadReadme(
	workspacePath: string,
	thread: ThreadRecord,
	blockers: BlockerRecord[],
	decisions: DecisionRecord[],
	tasks: TaskRecord[] = [],
	activeTaskPath?: string,
	runOutcomes: ReadonlyMap<string, TaskRunOutcome> = new Map(),
): Promise<RenderResult> {
	const readme = safeThreadReadmePath(workspacePath, thread);
	return writeGeneratedSection(
		readme,
		threadReadmeFallback(thread),
		threadGeneratedSection(thread, blockers, decisions, tasks, activeTaskPath, runOutcomes),
	);
}
