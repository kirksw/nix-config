import type {
	CandidateRecord,
	DecisionRecord,
	ThreadRecord,
} from "../core/schema.js";
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { newId, nowIso } from "../core/store.js";
import { readMarkdownThreads, writeMarkdownRecord } from "../core/markdown-store.ts";

export type ActiveThreadGetter = (
	workspacePath: string | null,
) => string | undefined;

function stripQuotes(text: string): string {
	return text.trim().replace(/^['"]|['"]$/g, "");
}

export async function handleCapture(
	args: string,
	agentos: AgentOsContext,
	getActive: ActiveThreadGetter,
): Promise<string> {
	requireWritable(agentos);
	const text = stripQuotes(args);
	const activeSlug = getActive(agentos.workspacePath);
	const threads = await readMarkdownThreads(agentos.workspacePath);
	const activeThread = activeSlug
		? threads.find((t) => t.slug === activeSlug)
		: undefined;
	const now = nowIso();

	if (!text) {
		const candidate: CandidateRecord = {
			id: newId("cand"),
			type: "candidate",
			createdAt: now,
			updatedAt: now,
			text: "Agent-assisted extraction requested for current Pi session.",
			source: "pi",
			status: "review",
			threadId: activeThread?.id,
			reason: activeThread
				? "empty capture command on active thread"
				: "empty capture command without active thread",
		};
		await writeMarkdownRecord(agentos.workspacePath, activeThread?.slug, "candidate", candidate.id, candidate.text, candidate.reason);
		return [
			`# Agent OS capture queued`,
			"",
			`- Candidate: ${candidate.id}`,
			`- Thread: ${activeThread?.slug ?? "inbox/review"}`,
		].join("\n");
	}

	const decisionMatch = text.match(/^(decision|decided):\s*(.+)$/i);
	if (decisionMatch && activeThread) {
		const decision: DecisionRecord = {
			id: newId("dec"),
			type: "decision",
			createdAt: now,
			updatedAt: now,
			text: decisionMatch[2],
			source: "pi",
			threadId: activeThread.id,
		};
		await writeMarkdownRecord(agentos.workspacePath, activeThread.slug, "decision", decision.id, decision.text);
		return [
			`# Agent OS decision captured`,
			"",
			`- Decision: ${decision.text}`,
			`- Thread: ${activeThread.slug}`,
		].join("\n");
	}

	const candidate: CandidateRecord = {
		id: newId("cand"),
		type: "candidate",
		createdAt: now,
		updatedAt: now,
		text,
		source: "pi",
		status: "review",
		threadId: activeThread?.id,
		reason: activeThread
			? "explicit capture on active thread"
			: "no active thread; queued for inbox review",
	};
	await writeMarkdownRecord(agentos.workspacePath, activeThread?.slug, "candidate", candidate.id, candidate.text, candidate.reason);
	return [
		`# Agent OS candidate captured`,
		"",
		`- Candidate: ${candidate.id}`,
		`- Thread: ${activeThread?.slug ?? "inbox/review"}`,
	].join("\n");
}
