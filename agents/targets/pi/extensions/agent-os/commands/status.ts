/// <reference path="../types.d.ts" />
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { AgentOsContext } from "../core/repo.js";
import { gitDirty } from "../core/repo.js";
import { inferMode } from "../core/mode.js";
import { unreadMessages } from "../core/mailbox.js";

export type ActiveBindingLookup = (
	workspacePath: string | null,
) => { thread?: string; task?: string };

function tableCell(value: string): string {
	return value.replace(/\r?\n/g, " ").replace(/\|/g, "\\|").trim() || "n/a";
}

export async function statusMarkdown(
	agentos: AgentOsContext,
	activeBinding: ActiveBindingLookup,
): Promise<string> {
	const binding = activeBinding(agentos.workspacePath);
	const mode = inferMode(binding.thread, binding.task);
	const dirty =
		agentos.repoExists && agentos.repoPath
			? await gitDirty(agentos.repoPath)
			: "repo missing";
	const unread = agentos.workspacePath
		? (await unreadMessages(agentos.workspacePath, mode, binding.thread, binding.task)).length
		: 0;
	const rows: Array<[string, string]> = [
		["Mode", mode],
		["Policy role", agentos.policy?.role ?? "unresolved"],
		["Policy read", agentos.policy?.readDescription ?? "unresolved"],
		["Policy write", agentos.policy?.writeDescription ?? "unresolved"],
		["Thread", binding.thread ?? "none"],
		["Task", binding.task ?? "none"],
		["Unread mailbox", String(unread)],
		["Repo", agentos.repoPath ?? "n/a"],
		["Repo exists", agentos.repoExists ? "yes" : "no"],
		["Scope", agentos.scope ?? "unknown"],
		["Scope reason", agentos.scopeReason],
		["Workspace", agentos.workspacePath ?? "n/a"],
		["Store", agentos.storePath ?? "n/a"],
		["Writes", agentos.writeEnabled ? "enabled" : `disabled (${agentos.writeDisabledReason})`],
		["Git state", dirty],
	];
	return [
		"# Agent OS status",
		"",
		"| Field | Value |",
		"| --- | --- |",
		...rows.map(([field, value]) => `| ${field} | ${tableCell(value)} |`),
		"",
	].join("\n");
}

export async function handleStatus(
	_args: string,
	ctx: ExtensionContext,
	agentos: AgentOsContext,
	activeBinding: ActiveBindingLookup,
): Promise<string> {
	void ctx;
	return statusMarkdown(agentos, activeBinding);
}
