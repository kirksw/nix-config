import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { assertPolicyWrite } from "../core/policy.ts";
import { readMarkdownData } from "../core/markdown-store.ts";
import {
	createTask,
	deleteOpenTasks,
	listTasks,
	reportTaskRun,
	resolveTask,
	runTask,
	transitionTask,
	taskRelativePath,
} from "../core/task.js";
import type { FactoryRunLauncher } from "../core/task.js";
import type { AgentOsBinding } from "../core/binding.js";
import { latestTaskOutcomes, renderThreadReadme } from "../render/thread-readme.js";

export type ActiveBinding = { thread?: string; task?: string };
export type BindingSetter = (binding: ActiveBinding) => void;

async function refreshThreadReadme(
	agentos: AgentOsContext,
	threadSlug: string,
	activeTaskPath?: string,
): Promise<void> {
	const data = await readMarkdownData(agentos.workspacePath);
	const thread = data.threads.find((item) => item.slug === threadSlug);
	if (!thread) return;
	const tasks = data.tasks.filter((task) => task.thread === threadSlug);
	await renderThreadReadme(
		agentos.workspacePath,
		thread,
		data.blockers,
		data.decisions,
		tasks,
		activeTaskPath,
		await latestTaskOutcomes(tasks),
	);
}

export async function handleTask(
	args: string,
	agentos: AgentOsContext,
	active: ActiveBinding,
	setBinding: BindingSetter,
	launchFactoryRun?: FactoryRunLauncher,
): Promise<{ output: string; binding: AgentOsBinding | undefined }> {
	requireWritable(agentos);
	const value = args.trim();
	if (!value || value === "-h" || value === "--help" || value === "help") {
		if (!value || value === "help") {
			if (!active.thread) throw new Error("select a thread before listing tasks");
			const packages = await listTasks(agentos.workspacePath, active.thread);
			const lines = [`# Tasks for ${active.thread}`, ""];
			if (packages.length === 0) lines.push("No open tasks.");
			else {
				for (const pkg of packages) {
					const marker = active.task && path.resolve(active.task) === path.resolve(pkg.path) ? " ←" : "";
					lines.push(`- **${pkg.id}** — ${pkg.status} — ${pkg.title}${marker}`);
				}
			}
			lines.push("", "Actions:", "- `/agent-os task <id>` bind a task", "- `/agent-os task spar <title>` spar and create a draft", "- `/agent-os task status <id> <state>` transition a task", "- `/agent-os task run [id]` launch a factory run", "- `/agent-os task run-report <id> <success|failure> [note]` report a run", "- `/agent-os task accept|reject <id>` finish review");
			return { output: lines.join("\\n"), binding: undefined };
		}
		return { output: "Usage: /agent-os task [id|path|clear|delete-all|spar <title>|run [id]|run-report <id> <success|failure> [note]|accept <id>|reject <id>|status <id> <state>]", binding: undefined };
	}
	const runMatch = value.match(/^run(?:\s+(\S+))?$/);
	if (runMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot start a task run");
		if (!active.thread) throw new Error("select a thread before running a task");
		const input = runMatch[1] ?? active.task;
		if (!input) throw new Error("usage: /agent-os task run <id>");
		const current = await resolveTask(agentos.workspacePath, active.thread, input);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const run = await runTask(agentos.workspacePath, active.thread, input, launchFactoryRun);
		await refreshThreadReadme(agentos, active.thread, active.task);
		return { output: `Started task ${run.task.id}; run report ${taskRelativePath(agentos.workspacePath, run.runReportPath)}`, binding: undefined };
	}
	const reportMatch = value.match(/^run-report\s+(\S+)\s+(success|failure)(?:\s+([\s\S]*))?$/);
	if (value === "run-report" || value.startsWith("run-report ") || reportMatch) {
		if (!active.thread) throw new Error("select a thread before reporting a task run");
		if (!reportMatch) throw new Error("usage: /agent-os task run-report <id> <success|failure> [note]");
		const [, id, outcome, note] = reportMatch;
		if (agentos.mode === "Factory" && agentos.taskPath) {
			const selected = await resolveTask(agentos.workspacePath, active.thread, id);
			if (path.resolve(selected.path) !== path.resolve(agentos.taskPath)) throw new Error("FactoryOS task binding is fixed");
		}
		const updated = await reportTaskRun(agentos.workspacePath, active.thread, id, outcome as "success" | "failure", note);
		await refreshThreadReadme(agentos, active.thread, active.task);
		return { output: `Updated task ${updated.id} to review`, binding: undefined };
	}
	const acceptMatch = value.match(/^accept\s+(\S+)$/);
	if (value === "accept" || acceptMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot accept a task");
		if (!active.thread) throw new Error("select a thread before accepting a task");
		if (!acceptMatch) throw new Error("usage: /agent-os task accept <id>");
		const [, id] = acceptMatch;
		const current = await resolveTask(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionTask(agentos.workspacePath, active.thread, id, "done");
		await refreshThreadReadme(agentos, active.thread, active.task);
		return { output: `Accepted task ${updated.id}; status is done`, binding: undefined };
	}
	const rejectMatch = value.match(/^reject\s+(\S+)$/);
	if (value === "reject" || rejectMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot reject a task");
		if (!active.thread) throw new Error("select a thread before rejecting a task");
		if (!rejectMatch) throw new Error("usage: /agent-os task reject <id>");
		const [, id] = rejectMatch;
		const current = await resolveTask(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionTask(agentos.workspacePath, active.thread, id, "failed");
		await refreshThreadReadme(agentos, active.thread, active.task);
		return { output: `Rejected task ${updated.id}; status is failed`, binding: undefined };
	}
	const statusMatch = value.match(/^status\s+(\S+)\s+(\S+)$/);
	if (value === "status" || statusMatch) {
		if (!active.thread) throw new Error("select a thread before changing task status");
		if (!statusMatch) throw new Error("usage: /agent-os task status <id> <state>");
		const [, id, status] = statusMatch;
		const current = await resolveTask(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionTask(agentos.workspacePath, active.thread, id, status as Parameters<typeof transitionTask>[3]);
		await refreshThreadReadme(agentos, active.thread, active.task);
		return { output: `Updated task ${updated.id} to ${updated.status}`, binding: undefined };
	}
	if (value === "delete-all") {
		if (agentos.mode === "Factory") throw new Error("FactoryOS task binding is fixed");
		if (!active.thread) throw new Error("select a thread before deleting tasks");
		const deleted = await deleteOpenTasks(agentos.workspacePath, active.thread);
		setBinding({ thread: active.thread });
		return {
			output: deleted.length
				? `Deleted ${deleted.length} open task(s) for ${active.thread}`
				: `No open tasks for ${active.thread}`,
			binding: undefined,
		};
	}
	if (value === "clear") {
		if (agentos.mode === "Factory") {
			throw new Error("FactoryOS task binding is fixed");
		}
		setBinding({ thread: active.thread });
		return { output: "Cleared the active task", binding: undefined };
	}
	if (value === "spar" || value.startsWith("spar ")) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS task binding is fixed");
		if (!active.thread) throw new Error("select a thread before creating a task");
		const created = await createTask(agentos.workspacePath, active.thread, value.slice(4).trim());
		const relative = taskRelativePath(agentos.workspacePath, created.path);
		const binding: AgentOsBinding = {
			version: 1,
			thread: active.thread,
			task: relative,
			project: process.env.AGENT_OS_PROJECT_ROOT ?? process.cwd(),
			workspace: agentos.repoPath ?? undefined,
			scope: agentos.scope ?? undefined,
			profile: process.env.NAX_PROFILE,
			updatedAt: new Date().toISOString(),
		};
		setBinding({ thread: active.thread, task: created.path });
		return {
			output: `Created draft task ${created.id} (${relative}) and bound it for sparring`,
			binding,
		};
	}
	if (!active.thread) throw new Error("select a thread before binding a task");
	if (agentos.mode === "Factory" && agentos.taskPath) {
		const current = path.resolve(agentos.taskPath);
		const requested = path.resolve(agentos.workspacePath, "threads", active.thread, "tasks", value);
		const workspaceRequested = path.resolve(agentos.workspacePath, value);
		if (value !== path.basename(current) && path.resolve(value) !== current && requested !== current && workspaceRequested !== current) {
			throw new Error("FactoryOS task binding is fixed");
		}
	}
	const resolved = await resolveTask(agentos.workspacePath, active.thread,
		agentos.mode === "Factory" && agentos.taskPath ? agentos.taskPath : value);
	if (agentos.mode === "Factory" && agentos.taskPath &&
		resolved.path !== agentos.taskPath) {
		throw new Error("FactoryOS task binding is fixed");
	}
	const relative = taskRelativePath(agentos.workspacePath, resolved.path);
	const binding: AgentOsBinding = {
		version: 1,
		thread: active.thread,
		task: relative,
		project: process.env.AGENT_OS_PROJECT_ROOT ?? process.cwd(),
		workspace: agentos.repoPath ?? undefined,
		scope: agentos.scope ?? undefined,
		profile: process.env.NAX_PROFILE,
		updatedAt: new Date().toISOString(),
	};
	setBinding({ thread: active.thread, task: resolved.path });
	return { output: `Bound task ${resolved.id} (${relative})`, binding };
}
