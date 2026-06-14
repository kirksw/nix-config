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

function threadLine(thread: ThreadRecord): string {
	return `- [${thread.title}](threads/${thread.slug}/) — ${thread.kind}, stage: ${thread.stage}`;
}

export function trackerSection(data: LifeOsData): string {
	const lines = ["# LifeOS Tracker", "", `Threads: ${data.threads.length}`, ""];
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
			lines.push(...stageThreads.map(threadLine));
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
	return lines.join("\n");
}

export function trackerFallback(): string {
	return [
		"# LifeOS Tracker",
		"",
		"This file is updated by the Pi LifeOS extension. Manual notes can live outside the generated block.",
		"",
		"<!-- lifeos:generated:start -->",
		"_Generated tracker state will appear here._",
		"<!-- lifeos:generated:end -->",
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
		"# LifeOS Focus\n\n",
		markdown,
	);
}
