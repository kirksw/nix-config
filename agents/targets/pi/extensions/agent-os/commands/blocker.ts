import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.ts";
import { requireWritable } from "../core/repo.ts";
import { assertPolicyWrite } from "../core/policy.ts";
import { readMarkdownData, readMarkdownThreads, writeBlockerDocument } from "../core/markdown-store.ts";
import type { BlockerRecord } from "../core/schema.ts";
import { newId, nowIso } from "../core/store.ts";

export type ActiveThreadGetter = (workspacePath: string | null) => string | undefined;

function stripQuotes(value: string): string {
	return value.trim().replace(/^['"]|['"]$/g, "");
}

export async function handleBlocker(
	args: string,
	agentos: AgentOsContext,
	getActive: ActiveThreadGetter,
): Promise<string> {
	requireWritable(agentos);
	if (agentos.policy.role === "FactoryOS") throw new Error("FactoryOS cannot manage blockers");
	const match = args.trim().match(/^(add|resolve)(?:\s+([\s\S]*))?$/);
	if (!match) throw new Error("usage: /agent-os blocker add <text> | resolve <id>");
	const action = match[1];
	const value = stripQuotes(match[2] ?? "");
	if (!value) throw new Error(`usage: /agent-os blocker ${action} <${action === "add" ? "text" : "id"}>`);

	if (action === "add") {
		const activeSlug = getActive(agentos.workspacePath);
		const id = newId("blk");
		const target = path.join(agentos.workspacePath, activeSlug ? "threads" : "inbox", ...(activeSlug ? [activeSlug, "blockers", `${id}.md`] : ["blockers", `${id}.md`]));
		assertPolicyWrite(agentos.policy, target);
		const thread = activeSlug
			? (await readMarkdownThreads(agentos.workspacePath)).find((item) => item.slug === activeSlug)
			: undefined;
		const now = nowIso();
		const blocker: BlockerRecord = {
			id,
			type: "blocker",
			createdAt: now,
			updatedAt: now,
			text: value,
			status: "open",
			threadId: thread?.id,
		};
		const file = await writeBlockerDocument(agentos.workspacePath, thread?.slug, blocker);
		return `# Agent OS blocker added\n\n- ID: ${blocker.id}\n- Path: ${file}`;
	}

	const blocker = (await readMarkdownData(agentos.workspacePath)).blockers.find((item) => item.id === value);
	if (!blocker) throw new Error(`blocker not found: ${value}`);
	if (blocker.status === "resolved") throw new Error(`blocker is already resolved: ${value}`);
	const resolved: BlockerRecord = { ...blocker, status: "resolved", updatedAt: nowIso() };
	const threadSlug = blocker.threadId?.replace(/^thread:/, "");
	const file = path.join(agentos.workspacePath, threadSlug ? "threads" : "inbox", ...(threadSlug ? [threadSlug, "blockers", `${resolved.id}.md`] : ["blockers", `${resolved.id}.md`]));
	assertPolicyWrite(agentos.policy, file);
	await writeBlockerDocument(agentos.workspacePath, threadSlug, resolved);
	return `# Agent OS blocker resolved\n\n- ID: ${resolved.id}\n- Path: ${file}`;
}
