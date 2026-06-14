/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type {
	BlockerRecord,
	DecisionRecord,
	ThreadRecord,
} from "../core/schema.js";
import type { RenderResult } from "./markdown.js";
import { writeGeneratedSection, yamlString } from "./markdown.js";

export function threadReadmeFallback(thread: ThreadRecord): string {
	return [
		"---",
		`title: ${yamlString(thread.title)}`,
		`slug: ${yamlString(thread.slug)}`,
		`kind: ${yamlString(thread.kind)}`,
		`status: ${yamlString(thread.status)}`,
		`stage: ${yamlString(thread.stage)}`,
		`created: ${yamlString(thread.createdAt)}`,
		"---",
		"",
		`# ${thread.title}`,
		"",
		"<!-- lifeos:generated:start -->",
		"_Generated LifeOS state will appear here._",
		"<!-- lifeos:generated:end -->",
		"",
		"## Manual notes",
		"",
	].join("\n");
}

export function threadGeneratedSection(
	thread: ThreadRecord,
	blockers: BlockerRecord[],
	decisions: DecisionRecord[],
): string {
	const openBlockers = blockers.filter(
		(b) => b.threadId === thread.id && b.status !== "resolved",
	);
	const threadDecisions = decisions
		.filter((d) => d.threadId === thread.id)
		.slice(-5)
		.reverse();
	return [
		"## LifeOS state",
		"",
		`- Status: ${thread.status}`,
		`- Stage: ${thread.stage}`,
		`- Kind: ${thread.kind}`,
		`- Updated: ${thread.updatedAt ?? thread.createdAt}`,
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

function safeThreadReadmePath(workspacePath: string, thread: ThreadRecord): string {
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
): Promise<RenderResult> {
	const readme = safeThreadReadmePath(workspacePath, thread);
	return writeGeneratedSection(
		readme,
		threadReadmeFallback(thread),
		threadGeneratedSection(thread, blockers, decisions),
	);
}
