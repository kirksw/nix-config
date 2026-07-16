/// <reference path="../types.d.ts" />
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { promoteOutputToWiki } from "../core/promotion.ts";

export async function handlePromote(args: string, agentos: AgentOsContext, confirm: (title: string, body: string) => Promise<boolean>): Promise<string> {
	requireWritable(agentos);
	if (agentos.mode !== "OS") throw new Error("Factory output promotion is an OS action");
	const [thread, workpackage] = args.trim().split(/\s+/);
	if (!thread || !workpackage) throw new Error("usage: /agent-os promote <thread> <workpackage>");
	const proposal = await promoteOutputToWiki(agentos.workspacePath, thread, workpackage, false);
	const body = proposal.files.length > 0 ? proposal.files.map((file) => `- ${file}`).join("\n") : "(no output files)";
	if (proposal.files.length === 0) return `No Factory output to promote for ${thread}/${workpackage}.`;
	if (!(await confirm("Promote Factory output to wiki?", body))) return "Promotion cancelled; wiki unchanged.";
	const promoted = await promoteOutputToWiki(agentos.workspacePath, thread, workpackage, true);
	return `Promoted ${promoted.files.length} file(s) to wiki from ${thread}/${workpackage}.`;
}
