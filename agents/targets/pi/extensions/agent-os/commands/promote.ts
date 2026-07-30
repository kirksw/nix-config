/// <reference path="../types.d.ts" />
import type { AgentOsContext } from "../core/repo.ts";
import { requireWritable } from "../core/repo.ts";
import { promoteArtifactToWiki } from "../core/promotion.ts";

export async function handlePromote(args: string, agentos: AgentOsContext, confirm: (title: string, body: string) => Promise<boolean>): Promise<string> {
	requireWritable(agentos);
	if (agentos.mode !== "OS") throw new Error("Factory artifact promotion is an OS action");
	const [thread, task] = args.trim().split(/\s+/);
	if (!thread || !task) throw new Error("usage: /agent-os promote <thread> <task>");
	const proposal = await promoteArtifactToWiki(agentos.workspacePath, thread, task, false);
	const body = proposal.files.length > 0 ? proposal.files.map((file) => `- ${file}`).join("\n") : "(no artifact files)";
	if (proposal.files.length === 0) return `No Factory artifact to promote for ${thread}/${task}.`;
	if (!(await confirm("Promote Factory artifact to wiki?", body))) return "Promotion cancelled; wiki unchanged.";
	const promoted = await promoteArtifactToWiki(agentos.workspacePath, thread, task, true);
	return `Promoted ${promoted.files.length} file(s) to wiki from ${thread}/${task}.`;
}
