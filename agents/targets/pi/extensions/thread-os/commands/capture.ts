import type {
	CandidateRecord,
	DecisionRecord,
	ThreadRecord,
} from "../core/schema.js";
import type { ThreadOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { appendRecord, newId, nowIso, readJsonl } from "../core/store.js";

export type ActiveThreadGetter = (
	workspacePath: string | null,
) => string | undefined;

function stripQuotes(text: string): string {
	return text.trim().replace(/^['"]|['"]$/g, "");
}

export async function handleCapture(
	args: string,
	lifeos: ThreadOsContext,
	getActive: ActiveThreadGetter,
): Promise<string> {
	requireWritable(lifeos);
	const text = stripQuotes(args);
	const activeSlug = getActive(lifeos.workspacePath);
	const threads = await readJsonl<ThreadRecord>(lifeos.storePath, "threads");
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
		await appendRecord(lifeos.storePath, "candidates", candidate);
		return [
			`# Thread OS capture queued`,
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
		await appendRecord(lifeos.storePath, "decisions", decision);
		return [
			`# Thread OS decision captured`,
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
	await appendRecord(lifeos.storePath, "candidates", candidate);
	return [
		`# Thread OS candidate captured`,
		"",
		`- Candidate: ${candidate.id}`,
		`- Thread: ${activeThread?.slug ?? "inbox/review"}`,
	].join("\n");
}
