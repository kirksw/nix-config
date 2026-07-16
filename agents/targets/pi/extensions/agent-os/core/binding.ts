import * as path from "node:path";

export type AgentOsBinding = {
	version: 1;
	thread?: string;
	task?: string;
	project: string;
	workspace?: string;
	scope?: string;
	profile?: string;
	updatedAt: string;
};

export function shouldStartThreadSession(cwd: string): boolean {
	return path.basename(path.resolve(cwd)).endsWith("OS");
}

export type SessionEntry = {
	type: string;
	customType?: string;
	data?: unknown;
};

export function activeThreadFor(
	workspacePath: string | null,
	activeThreads: Map<string, string>,
	env: Record<string, string | undefined>,
): string | undefined {
	return env.AGENT_OS_THREAD_ID ?? (workspacePath ? activeThreads.get(workspacePath) : undefined);
}

export function activeTaskFor(
	env: Record<string, string | undefined>,
): string | undefined {
	return env.AGENT_OS_TASK;
}

export function bindRestoredThread(
	binding: AgentOsBinding | undefined,
	activeThreads: Map<string, string>,
	workspacePath: string | null,
): void {
	if (binding?.thread && workspacePath) activeThreads.set(workspacePath, binding.thread);
}

export function restoreBinding(
	entries: SessionEntry[],
	env: Record<string, string | undefined>,
): AgentOsBinding | undefined {
	if (env.AGENT_OS_THREAD_ID) return undefined;
	for (let i = entries.length - 1; i >= 0; i -= 1) {
		const entry = entries[i];
		if (entry?.type !== "custom" || entry.customType !== "agent-os-binding") continue;
		const data = entry.data;
		if (!data || typeof data !== "object") continue;
		const binding = data as Partial<AgentOsBinding>;
		if (typeof binding.thread !== "string" || typeof binding.project !== "string") continue;
		const workspace = binding.workspace?.endsWith("/workspace")
			? binding.workspace.slice(0, -"/workspace".length)
			: binding.workspace;
		env.AGENT_OS_THREAD_ID = binding.thread;
		if (binding.task) env.AGENT_OS_TASK = binding.task;
		else delete env.AGENT_OS_TASK;
		env.AGENT_OS_PROJECT_ROOT = binding.project;
		if (workspace) env.AGENT_OS_WORKSPACE_ROOT = workspace;
		if (binding.scope) env.AGENT_OS_SCOPE = binding.scope;
		return { ...binding, workspace } as AgentOsBinding;
	}
	return undefined;
}
