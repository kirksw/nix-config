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

export interface LifeOsContext {
	repoPath: string;
	repoExists: boolean;
	scope: Scope | null;
	scopeReason: string;
	workspacePath: string | null;
	storePath: string | null;
	writeEnabled: boolean;
	writeDisabledReason?: string;
}

export function defaultRepoPath(): string {
	return (
		process.env.LIFEOS_REPO ??
		path.join(process.env.HOME ?? "/Users/kisw", "git/github.com/kirksw/lifeOS")
	);
}

async function directoryExists(p: string): Promise<boolean> {
	try {
		const s = await fs.stat(p);
		return s.isDirectory();
	} catch {
		return false;
	}
}

export async function resolveLifeOsContext(
	ctx?: ExtensionContext,
): Promise<LifeOsContext> {
	const repoPath = defaultRepoPath();
	const repoExists = await directoryExists(repoPath);
	const scope: ScopeResolution = resolveScope(ctx);
	const workspacePath = scope.scope
		? path.join(repoPath, "workspaces", scope.scope)
		: null;
	const storePath = workspacePath
		? path.join(workspacePath, ".lifeos", "db")
		: null;
	const workspaceExists = workspacePath
		? await directoryExists(workspacePath)
		: false;

	let writeDisabledReason: string | undefined;
	if (!repoExists) writeDisabledReason = `LifeOS repo not found at ${repoPath}`;
	else if (!scope.scope)
		writeDisabledReason = `scope is ambiguous (${scope.reason})`;
	else if (!workspaceExists)
		writeDisabledReason = `workspace not found at ${workspacePath}`;

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
	lifeos: LifeOsContext,
): asserts lifeos is LifeOsContext & {
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
		throw new Error(lifeos.writeDisabledReason ?? "LifeOS writes are disabled");
	}
}
