import type { LifeOsData } from "../core/schema.ts";
import type { ScoredThread } from "../core/scoring.ts";

type FocusData = Pick<LifeOsData, "tasks" | "outcomes">;

export function focusMarkdown(scored: ScoredThread[], limit = 8, data?: FocusData): string {
	if (scored.length === 0) return "# Agent OS Focus\n\nNo active threads yet.\n";
	const lines = ["# Agent OS Focus", "", "Recommended threads:", ""];
	for (const item of scored.slice(0, limit)) {
		lines.push(`## ${item.thread.title}`);
		lines.push("");
		lines.push(`- Slug: ${item.thread.slug}`);
		lines.push(`- Score: ${item.score.toFixed(1)}`);
		lines.push(`- Status/stage: ${item.thread.status} / ${item.thread.stage}`);
		lines.push(`- Reasons: ${item.reasons.join(", ")}`);
		if (item.blockers.length > 0)
			lines.push(`- Blockers: ${item.blockers.map((b) => b.text).join("; ")}`);
		const tasks = data?.tasks.filter((task) => task.thread === item.thread.slug) ?? [];
		lines.push(`- Tasks: ${tasks.length === 0 ? "None" : tasks.map((task) => `${task.id} (${task.status})`).join(", ")}`);
		const outcomes = data?.outcomes.filter((outcome) => outcome.thread === item.thread.slug || outcome.thread === item.thread.id) ?? [];
		if (outcomes.length > 0) {
			lines.push(`- Outcomes: ${outcomes.map((outcome) => `${outcome.title} (${outcome.state})`).join(", ")}`);
		}
		if (item.metrics.length > 0)
			lines.push(`- Metrics: ${item.metrics.map((m) => m.name).join(", ")}`);
		lines.push("");
	}
	return lines.join("\n");
}
