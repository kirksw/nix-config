/// <reference path="../types.d.ts" />
import { execFile } from "node:child_process";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { promisify } from "node:util";
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { Scope } from "./schema.js";
import { resolveScope, type ScopeResolution } from "./scope.js";

const execFileAsync = promisify(execFile) as (
	file: string,
	args?: readonly string[],
	options?: Record<string, unknown>,
) => Promise<{ stdout: string; stderr: string }>;

export interface ThreadOsContext {
	repoPath: string | null;
	repoExists: boolean;
	scope: Scope | null;
	scopeReason: string;
	workspacePath: string | null;
	storePath: string | null;
	writeEnabled: boolean;
	writeDisabledReason?: string;
}

export function defaultRepoPath(scope: Scope | null): string | null {
	const home = process.env.HOME ?? "/Users/kisw";
	if (scope === "personal") {
		return (
			process.env.THREAD_OS_PERSONAL_REPO ??
			path.join(home, "git/github.com/kirksw/lifeOS")
		);
	}
	if (scope === "lunar") {
		return (
			process.env.THREAD_OS_WORK_REPO ??
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

async function resolveRepoAndWorkspacePath(
	repoPath: string,
): Promise<{ repoPath: string; workspacePath: string }> {
	const workspacePath = path.join(repoPath, "workspace");
	if (await directoryExists(workspacePath)) {
		return { repoPath, workspacePath };
	}

	const mainRepoPath = path.join(repoPath, "main");
	const mainWorkspacePath = path.join(mainRepoPath, "workspace");
	if (await directoryExists(mainWorkspacePath)) {
		return { repoPath: mainRepoPath, workspacePath: mainWorkspacePath };
	}

	return { repoPath, workspacePath };
}

export async function resolveThreadOsContext(
	ctx?: ExtensionContext,
): Promise<ThreadOsContext> {
	const scope: ScopeResolution = resolveScope(ctx);
	const configuredRepoPath = defaultRepoPath(scope.scope);
	const configuredRepoExists = configuredRepoPath
		? await directoryExists(configuredRepoPath)
		: false;
	const resolvedPaths =
		scope.scope && configuredRepoPath && configuredRepoExists
			? await resolveRepoAndWorkspacePath(configuredRepoPath)
			: null;
	const repoPath = resolvedPaths?.repoPath ?? configuredRepoPath;
	const repoExists = repoPath ? await directoryExists(repoPath) : false;
	const workspacePath = resolvedPaths?.workspacePath ?? null;
	const storePath = workspacePath
		? path.join(workspacePath, ".lifeos", "db")
		: null;
	const workspaceExists = workspacePath
		? await directoryExists(workspacePath)
		: false;

	let writeDisabledReason: string | undefined;
	if (!scope.scope) {
		writeDisabledReason = `scope is ambiguous (${scope.reason})`;
	} else if (!repoPath) {
		writeDisabledReason = `repo path could not be resolved for scope ${scope.scope}`;
	} else if (!repoExists) {
		writeDisabledReason = `Thread OS repo not found at ${repoPath}`;
	} else if (!workspaceExists) {
		writeDisabledReason = `workspace not found at ${workspacePath}`;
	}

	return {
		repoPath,
		repoExists,
		scope: scope.scope,
		scopeReason: scope.reason,
		workspacePath,
		storePath,
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
	lifeos: ThreadOsContext,
): asserts lifeos is ThreadOsContext & {
	scope: Scope;
	workspacePath: string;
	storePath: string;
} {
	if (
		!lifeos.writeEnabled ||
		!lifeos.scope ||
		!lifeos.workspacePath ||
		!lifeos.storePath
	) {
		throw new Error(
			lifeos.writeDisabledReason ?? "Thread OS writes are disabled",
		);
	}
}
