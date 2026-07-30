/// <reference path="../types.d.ts" />
import { execFile } from "node:child_process";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { promisify } from "node:util";
import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Scope } from "./schema.ts";
import { inferMode, type AgentOsMode } from "./mode.ts";
import { policyFor, type AgentOsPolicy } from "./policy.ts";
import { resolveTask } from "./task.ts";
import { resolveScope, type ScopeResolution } from "./scope.ts";
import { initializeWorkspace, validateWorkspaceLayout } from "./layout.ts";

const execFileAsync = promisify(execFile) as (
	file: string,
	args?: readonly string[],
	options?: Record<string, unknown>,
) => Promise<{ stdout: string; stderr: string }>;

export interface AgentOsContext {
	repoPath: string | null;
	repoExists: boolean;
	scope: Scope | null;
	scopeReason: string;
	workspacePath: string | null;
	storePath: string | null;
	mode: AgentOsMode;
	policy: AgentOsPolicy | null;
	thread?: string;
	taskPath?: string;
	writeEnabled: boolean;
	writeDisabledReason?: string;
}

export function defaultRepoPath(
	scope: Scope | null,
	includeBoundWorkspace = true,
): string | null {
	const boundWorkspace = process.env.AGENT_OS_WORKSPACE_ROOT;
	if (includeBoundWorkspace && boundWorkspace) return boundWorkspace;
	const home = process.env.HOME ?? "/Users/kisw";
	if (scope === "personal") {
		return (
			process.env.AGENT_OS_PERSONAL_REPO ??
			path.join(home, "git/github.com/kirksw/lifeOS")
		);
	}
	if (scope === "lunar") {
		return (
			process.env.AGENT_OS_WORK_REPO ??
			path.join(home, "git/github.com/kirksw/lunarOS")
		);
	}
	return null;
}

async function directoryExists(p: string): Promise<boolean> {
	try {
		const s = await fs.stat(p);
		return s.isDirectory();
	} catch {
		return false;
	}
}

function resolveWorkspacePath(repoPath: string): string {
	return path.join(repoPath, "workspace");
}

export async function resolveAgentOsContext(
	ctx?: ExtensionContext,
): Promise<AgentOsContext> {
	const scope: ScopeResolution = resolveScope(ctx);
	let repoPath = defaultRepoPath(scope.scope);
	let repoExists = repoPath ? await directoryExists(repoPath) : false;
	let workspacePath =
		scope.scope && repoPath && repoExists
			? resolveWorkspacePath(repoPath)
			: null;
	let workspaceExists = workspacePath
		? await directoryExists(workspacePath)
		: false;

	// A resumed session can retain the old worktree root. Prefer the scoped repo
	// when the bound root is no longer an Agent OS workspace.
	if (process.env.AGENT_OS_WORKSPACE_ROOT && (!repoExists || !workspaceExists)) {
		const fallbackRepoPath = defaultRepoPath(scope.scope, false);
		const fallbackRepoExists = fallbackRepoPath
			? await directoryExists(fallbackRepoPath)
			: false;
		const fallbackWorkspacePath =
			scope.scope && fallbackRepoPath && fallbackRepoExists
				? resolveWorkspacePath(fallbackRepoPath)
				: null;
		const fallbackWorkspaceExists = fallbackWorkspacePath
			? await directoryExists(fallbackWorkspacePath)
			: false;
		if (fallbackRepoExists && fallbackWorkspaceExists) {
			repoPath = fallbackRepoPath;
			repoExists = true;
			workspacePath = fallbackWorkspacePath;
			workspaceExists = true;
		}
	}

	let layoutError: string | undefined;
	if (workspacePath && workspaceExists) {
		try {
			await initializeWorkspace(workspacePath);
			await validateWorkspaceLayout(workspacePath);
		} catch (err) {
			layoutError = (err as Error).message;
		}
	}
	const storePath = workspacePath
		? path.join(workspacePath, "runtime")
		: null;
	const thread = process.env.AGENT_OS_THREAD_ID;
	const rawTask = process.env.AGENT_OS_TASK;
	let taskPath: string | undefined;
	let policyError: string | undefined;
	if (workspacePath && thread && rawTask) {
		try {
			taskPath = (await resolveTask(workspacePath, thread, rawTask)).path;
		} catch (err) {
			policyError = (err as Error).message;
		}
	}
	const mode = inferMode(thread, rawTask);
	let policy: AgentOsPolicy | null = null;
	if (workspacePath) {
		try {
			policy = policyFor(workspacePath, mode, thread, taskPath);
		} catch (err) {
			policyError ??= (err as Error).message;
		}
	}

	let writeDisabledReason: string | undefined;
	if (!scope.scope) {
		writeDisabledReason = `scope is ambiguous (${scope.reason})`;
	} else if (!repoPath) {
		writeDisabledReason = `repo path could not be resolved for scope ${scope.scope}`;
	} else if (!repoExists) {
		writeDisabledReason = `Agent OS repo not found at ${repoPath}`;
	} else if (!workspaceExists) {
		writeDisabledReason = `workspace not found at ${workspacePath}`;
	} else if (layoutError) {
		writeDisabledReason = `invalid Agent OS workspace layout: ${layoutError}`;
	} else if (policyError) {
		writeDisabledReason = `invalid Agent OS binding: ${policyError}`;
	}

	return {
		repoPath,
		repoExists,
		scope: scope.scope,
		scopeReason: scope.reason,
		workspacePath,
		storePath,
		mode,
		policy,
		thread,
		taskPath,
		writeEnabled: writeDisabledReason === undefined,
		writeDisabledReason,
	};
}

export async function gitDirty(repoPath: string): Promise<string> {
	try {
		const { stdout } = await execFileAsync(
			"git",
			["-C", repoPath, "status", "--short"],
			{
				timeout: 30_000,
				maxBuffer: 1024 * 1024,
			},
		);
		const lines = stdout.trim().split("\n").filter(Boolean);
		if (lines.length === 0) return "clean";
		return `${lines.length} changed file(s)`;
	} catch (err) {
		return `unknown (${(err as Error).message})`;
	}
}

export function requireWritable(
	agentos: AgentOsContext,
): asserts agentos is AgentOsContext & {
	scope: Scope;
	workspacePath: string;
	storePath: string;
	policy: AgentOsPolicy;
} {
	if (
		!agentos.writeEnabled ||
		!agentos.scope ||
		!agentos.workspacePath ||
		!agentos.storePath
	) {
		throw new Error(
			agentos.writeDisabledReason ?? "Agent OS writes are disabled",
		);
	}
}
