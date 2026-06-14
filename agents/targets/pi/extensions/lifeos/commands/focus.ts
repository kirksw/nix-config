import type { LifeOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { scoreThreads } from "../core/scoring.js";
import { readData } from "../core/store.js";
import { focusMarkdown } from "../render/focus.js";

export async function handleFocus(_args: string, lifeos: LifeOsContext): Promise<string> {
  requireWritable(lifeos);
  const data = await readData(lifeos.storePath);
  const scored = scoreThreads(data.threads, data.blockers, data.metrics, data.edges);
  return focusMarkdown(scored);
}
