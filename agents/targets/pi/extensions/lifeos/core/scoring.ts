import type {
	BlockerRecord,
	EdgeRecord,
	MetricRecord,
	ThreadRecord,
} from "./schema.js";

export interface ScoredThread {
	thread: ThreadRecord;
	score: number;
	reasons: string[];
	blockers: BlockerRecord[];
	metrics: MetricRecord[];
}

function n(value: number | undefined, fallback: number): number {
	if (typeof value !== "number" || Number.isNaN(value)) return fallback;
	return Math.max(0, Math.min(10, value));
}

export function scoreThreads(
	threads: ThreadRecord[],
	blockers: BlockerRecord[],
	metrics: MetricRecord[],
	edges: EdgeRecord[],
): ScoredThread[] {
	return threads
		.filter((thread) => thread.status !== "done")
		.map((thread) => {
			const openBlockers = blockers.filter(
				(b) => b.threadId === thread.id && b.status !== "resolved",
			);
			const metricIds = new Set(
				edges
					.filter(
						(e) => e.from === thread.id && e.relation === "contributes_to",
					)
					.map((e) => e.to),
			);
			const linkedMetrics = metrics.filter((m) => metricIds.has(m.id));
			const score =
				n(thread.impact, 5) * 2 +
				n(thread.confidence, 5) +
				n(thread.urgency, 5) * 1.5 +
				n(thread.salience, 5) +
				n(thread.manualOverride, 0) -
				n(thread.effort, 5) -
				openBlockers.length * 4 +
				linkedMetrics.length;
			const reasons = [
				`impact ${n(thread.impact, 5)}`,
				`confidence ${n(thread.confidence, 5)}`,
				`urgency ${n(thread.urgency, 5)}`,
				`effort ${n(thread.effort, 5)}`,
				`salience ${n(thread.salience, 5)}`,
			];
			if (openBlockers.length > 0)
				reasons.push(`${openBlockers.length} blocker(s)`);
			if (linkedMetrics.length > 0)
				reasons.push(`${linkedMetrics.length} metric link(s)`);
			if (thread.manualOverride)
				reasons.push(`manual override ${thread.manualOverride}`);
			return {
				thread,
				score,
				reasons,
				blockers: openBlockers,
				metrics: linkedMetrics,
			};
		})
		.sort((a, b) => b.score - a.score);
}
