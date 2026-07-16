/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";

export const WORKSPACE_DIRECTORIES = ["inbox", "threads", "wiki", "runtime", "outcomes"] as const;
export const THREAD_DIRECTORIES = ["plans", "research", "artifacts", "decisions", "blockers", "candidates", "sessions", "tasks"] as const;
export const TASK_DIRECTORIES = ["input", "runs", "artifacts"] as const;

async function directoryNames(root: string): Promise<string[]> {
	const entries = await fs.readdir(root, { withFileTypes: true }).catch(() => []);
	return entries.filter((entry) => entry.isDirectory()).map((entry) => entry.name);
}

export async function validateWorkspaceLayout(workspacePath: string): Promise<void> {
	const actual = await directoryNames(workspacePath);
	const unexpected = actual.filter((name) => !(WORKSPACE_DIRECTORIES as readonly string[]).includes(name));
	if (unexpected.length > 0) throw new Error(`non-canonical workspace directories: ${unexpected.join(", ")}`);
	const missing = WORKSPACE_DIRECTORIES.filter((name) => !actual.includes(name));
	if (missing.length > 0) throw new Error(`workspace missing canonical directories: ${missing.join(", ")}`);
}

export async function initializeWorkspace(workspacePath: string): Promise<void> {
	await fs.mkdir(workspacePath, { recursive: true });
	await Promise.all(WORKSPACE_DIRECTORIES.map((directory) => fs.mkdir(path.join(workspacePath, directory), { recursive: true })));
}

export const ensureWorkspaceLayout = initializeWorkspace;
export const assertWorkspaceLayout = validateWorkspaceLayout;

export async function initializeThread(workspacePath: string, slug: string): Promise<string> {
	if (!slug || slug.includes("/") || slug.includes("\\")) throw new Error("thread slug must be a directory-safe path segment");
	const root = path.join(workspacePath, "threads", slug);
	await fs.mkdir(root, { recursive: true });
	await Promise.all(THREAD_DIRECTORIES.map((directory) => fs.mkdir(path.join(root, directory), { recursive: true })));
	return root;
}

export async function validateTaskLayout(bundlePath: string): Promise<void> {
	const entries = await fs.readdir(bundlePath).catch(() => []);
	const expected = ["package.md", ...TASK_DIRECTORIES];
	const missing = expected.filter((name) => !entries.includes(name));
	const unexpected = entries.filter((name) => !expected.includes(name));
	if (missing.length || unexpected.length) throw new Error(`non-canonical task bundle: ${bundlePath}`);
}
