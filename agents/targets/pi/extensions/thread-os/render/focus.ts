import type { ScoredThread } from "../core/scoring.js";

export function focusMarkdown(scored: ScoredThread[], limit = 8): string {
	if (scored.length === 0) return "# Thread OS Focus\n\nNo active threads yet.\n";
	const lines = ["# Thread OS Focus", "", "Recommended threads:", ""];
	for (const item of scored.slice(0, limit)) {
		lines.push(`## ${item.thread.title}`);
		lines.push("");
		lines.push(`- Slug: ${item.thread.slug}`);
		lines.push(`- Score: ${item.score.toFixed(1)}`);
		lines.push(`- Status/stage: ${item.thread.status} / ${item.thread.stage}`);
		lines.push(`- Reasons: ${item.reasons.join(", ")}`);
		if (item.blockers.length > 0)
			lines.push(`- Blockers: ${item.blockers.map((b) => b.text).join("; ")}`);
		if (item.metrics.length > 0)
			lines.push(`- Metrics: ${item.metrics.map((m) => m.name).join(", ")}`);
		lines.push("");
	}
	return lines.join("\n");
}
