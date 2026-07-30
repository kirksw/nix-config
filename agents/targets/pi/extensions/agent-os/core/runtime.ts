/// <reference path="../types.d.ts" />
import * as path from "node:path";
import type { AgentOsMode } from "./mode.ts";

export interface RuntimeScope {
	mode: AgentOsMode;
	thread?: string;
	task?: string;
}

/** Normalize a task id, bundle path, or package.md path to its scope name. */
export function normalizeTaskId(value: string | undefined): string | undefined {
	if (!value?.trim()) return undefined;
	const parts = value.trim().replaceAll("\\", "/").split("/").filter(Boolean);
	if (parts.length === 0) return undefined;
	let name = parts.at(-1)!;
	if (name.toLowerCase() === "package.md") {
		name = parts.at(-2) ?? "";
	}
	return name.replace(/\.md$/i, "") || undefined;
}

function scopeSegment(value: string | undefined, label: string): string {
	const segment = value?.trim();
	if (!segment || segment === "." || segment === ".." || segment.includes("/") || segment.includes("\\")) {
		throw new Error(`${label} must be a single path segment`);
	}
	return segment;
}

export function runtimeScopePath(workspacePath: string, scope: RuntimeScope): string {
	if (scope.mode === "OS") return path.join(workspacePath, "runtime", "os");
	const thread = scopeSegment(scope.thread, "thread");
	const threadPath = path.join(workspacePath, "runtime", "threads", thread);
	if (scope.mode === "Thread") return threadPath;
	const task = normalizeTaskId(scope.task);
	if (!task) throw new Error("task is required for Factory runtime scope");
	return path.join(threadPath, "tasks", scopeSegment(task, "task"));
}

export function runtimeFilePath(
	workspacePath: string,
	file: "mailbox" | "events",
	scope: RuntimeScope,
): string {
	return path.join(runtimeScopePath(workspacePath, scope), `${file}.jsonl`);
}
