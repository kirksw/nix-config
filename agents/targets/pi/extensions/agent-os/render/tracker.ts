/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type { LifeOsData, ThreadRecord } from "../core/schema.js";
import type { RenderResult } from "./markdown.js";
import { writeGeneratedSection } from "./markdown.js";

function groupBy<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
	const grouped = new Map<string, T[]>();
	for (const item of items) {
		const k = key(item);
		grouped.set(k, [...(grouped.get(k) ?? []), item]);
	}
	return grouped;
}

function threadLine(thread: ThreadRecord, data: LifeOsData): string {
	const owned = data.tasks.filter((task) => task.thread === thread.slug);
	const openBlockers = data.blockers.filter((blocker) =>
		(blocker.threadId === thread.id || blocker.threadId === thread.slug) && blocker.status !== "resolved",
	).length;
	const progress = owned.length === 0
		? "none"
		: owned.map((task) => `${task.id} (${task.status})`).join(", ");
	return `- [${thread.title}](threads/${thread.slug}/) — ${thread.kind}, status: ${thread.status}, stage: ${thread.stage}, open blockers: ${openBlockers}, tasks: ${progress}`;
}

export function trackerSection(data: LifeOsData): string {
	const lines = ["# Agent OS Tracker", "", `Threads: ${data.threads.length}`, ""];
	for (const [status, threads] of groupBy(
		data.threads,
		(thread) => thread.status,
	)) {
		lines.push(`## ${status}`);
		lines.push("");
		for (const [stage, stageThreads] of groupBy(
			threads,
			(thread) => thread.stage || "unspecified",
		)) {
			lines.push(`### ${stage}`);
			lines.push("");
			lines.push(...stageThreads.map((thread) => threadLine(thread, data)));
			lines.push("");
		}
	}

	const reviewCandidates = data.candidates.filter((c) => c.status === "review");
	lines.push("## Review queues", "");
	lines.push(`- Candidates: ${reviewCandidates.length}`);
	lines.push(
		`- Open blockers: ${data.blockers.filter((b) => b.status !== "resolved").length}`,
	);
	lines.push(`- Metrics: ${data.metrics.length}`);
	lines.push(`- Tasks: ${data.tasks.length}`);
	return lines.join("\n");
}

export function trackerFallback(): string {
	return [
		"# Agent OS Tracker",
		"",
		"This file is updated by the Pi Agent OS extension. Manual notes can live outside the generated block.",
		"",
		"<!-- agent-os:generated:start -->",
		"_Generated tracker state will appear here._",
		"<!-- agent-os:generated:end -->",
		"",
	].join("\n");
}

export async function renderTracker(
	workspacePath: string,
	data: LifeOsData,
): Promise<RenderResult> {
	return writeGeneratedSection(
		path.join(workspacePath, "TRACKER.md"),
		trackerFallback(),
		trackerSection(data),
	);
}

export async function renderFocus(
	workspacePath: string,
	markdown: string,
): Promise<RenderResult> {
	return writeGeneratedSection(
		path.join(workspacePath, "FOCUS.md"),
		"# Agent OS Focus\n\n",
		markdown,
	);
}
