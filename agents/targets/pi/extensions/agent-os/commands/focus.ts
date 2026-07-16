import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { scoreThreads } from "../core/scoring.js";
import { readMarkdownData } from "../core/markdown-store.ts";
import { focusMarkdown } from "../render/focus.js";

export async function handleFocus(
	_args: string,
	agentos: AgentOsContext,
): Promise<string> {
	requireWritable(agentos);
	const data = await readMarkdownData(agentos.workspacePath);
	const scored = scoreThreads(
		data.threads,
		data.blockers,
		data.metrics,
		data.edges,
	);
	return focusMarkdown(scored, 8, data);
}
