/// <reference path="../types.d.ts" />
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { LifeOsContext } from "../core/repo.js";
import { gitDirty } from "../core/repo.js";

export type ActiveThreadLookup = (
	workspacePath: string | null,
) => string | undefined;

export async function statusMarkdown(
	lifeos: LifeOsContext,
	activeThread: ActiveThreadLookup,
): Promise<string> {
	const dirty = lifeos.repoExists
		? await gitDirty(lifeos.repoPath)
		: "repo missing";
	return [
		"# LifeOS status",
		"",
		`- Repo: ${lifeos.repoPath}`,
		`- Repo exists: ${lifeos.repoExists ? "yes" : "no"}`,
		`- Scope: ${lifeos.scope ?? "unknown"}`,
		`- Scope reason: ${lifeos.scopeReason}`,
		`- Workspace: ${lifeos.workspacePath ?? "n/a"}`,
		`- Store: ${lifeos.storePath ?? "n/a"}`,
		`- Active thread: ${activeThread(lifeos.workspacePath) ?? "none"}`,
		`- Writes: ${lifeos.writeEnabled ? "enabled" : `disabled (${lifeos.writeDisabledReason})`}`,
		`- Git state: ${dirty}`,
		"",
	].join("\n");
}

export async function handleStatus(
	_args: string,
	ctx: ExtensionContext,
	lifeos: LifeOsContext,
	activeThread: ActiveThreadLookup,
): Promise<string> {
	void ctx;
	return statusMarkdown(lifeos, activeThread);
}
