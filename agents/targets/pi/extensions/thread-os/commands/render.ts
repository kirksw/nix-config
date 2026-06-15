import type { ThreadOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { scoreThreads } from "../core/scoring.js";
import { readData } from "../core/store.js";
import { focusMarkdown } from "../render/focus.js";
import { renderThreadReadme } from "../render/thread-readme.js";
import { renderFocus, renderTracker } from "../render/tracker.js";

export async function handleRender(
	_args: string,
	lifeos: ThreadOsContext,
): Promise<string> {
	requireWritable(lifeos);
	const data = await readData(lifeos.storePath);
	const scored = scoreThreads(
		data.threads,
		data.blockers,
		data.metrics,
		data.edges,
	);
	const results = [
		await renderTracker(lifeos.workspacePath, data),
		await renderFocus(lifeos.workspacePath, focusMarkdown(scored)),
	];
	for (const thread of data.threads) {
		results.push(
			await renderThreadReadme(
				lifeos.workspacePath,
				thread,
				data.blockers,
				data.decisions,
			),
		);
	}

	const changed = results.filter((r) => r.changed).length;
	const warnings = results.filter((r) => r.warning);
	return [
		"# Thread OS render",
		"",
		`- Files considered: ${results.length}`,
		`- Files changed: ${changed}`,
		...warnings.map((r) => `- Warning ${r.path}: ${r.warning}`),
	].join("\n");
}
