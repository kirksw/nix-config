import type { AgentOsContext } from "../core/repo.ts";
import { requireWritable } from "../core/repo.ts";
import { scoreThreads } from "../core/scoring.ts";
import { readMarkdownData } from "../core/markdown-store.ts";
import { focusMarkdown } from "../render/focus.ts";

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
