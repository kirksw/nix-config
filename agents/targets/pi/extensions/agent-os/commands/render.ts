import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { scoreThreads } from "../core/scoring.js";
import { readMarkdownData } from "../core/markdown-store.ts";
import { focusMarkdown } from "../render/focus.js";
import { latestTaskOutcomes, renderThreadReadme } from "../render/thread-readme.js";
import { renderFocus, renderTracker } from "../render/tracker.js";

export async function handleRender(
	_args: string,
	agentos: AgentOsContext,
	active?: { task?: string },
): Promise<string> {
	requireWritable(agentos);
	const data = await readMarkdownData(agentos.workspacePath);
	const scored = scoreThreads(
		data.threads,
		data.blockers,
		data.metrics,
		data.edges,
	);
	const results = [
		await renderTracker(agentos.workspacePath, data),
		await renderFocus(agentos.workspacePath, focusMarkdown(scored, 8, data)),
	];
	for (const thread of data.threads) {
		const tasks = data.tasks.filter((task) => task.thread === thread.slug);
		results.push(
			await renderThreadReadme(
				agentos.workspacePath,
				thread,
				data.blockers,
				data.decisions,
				tasks,
				active?.task,
				await latestTaskOutcomes(tasks),
			),
		);
	}

	const changed = results.filter((r) => r.changed).length;
	const warnings = results.filter((r) => r.warning);
	return [
		"# Agent OS render",
		"",
		`- Files considered: ${results.length}`,
		`- Files changed: ${changed}`,
		...warnings.map((r) => `- Warning ${r.path}: ${r.warning}`),
	].join("\n");
}
