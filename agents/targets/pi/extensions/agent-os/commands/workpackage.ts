import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { assertPolicyWrite } from "../core/policy.ts";
import {
	createWorkpackage,
	deleteOpenWorkpackages,
	listWorkpackages,
	resolveWorkpackage,
	transitionWorkpackage,
	workpackageRelativePath,
} from "../core/workpackage.js";
import type { AgentOsBinding } from "../core/binding.js";

export type ActiveBinding = { thread?: string; workpackage?: string };
export type BindingSetter = (binding: ActiveBinding) => void;

export async function handleWorkpackage(
	args: string,
	agentos: AgentOsContext,
	active: ActiveBinding,
	setBinding: BindingSetter,
): Promise<{ output: string; binding: AgentOsBinding | undefined }> {
	requireWritable(agentos);
	const value = args.trim();
	if (!value || value === "-h" || value === "--help" || value === "help") {
		if (!value || value === "help") {
			if (!active.thread) throw new Error("select a thread before listing workpackages");
			const packages = await listWorkpackages(agentos.workspacePath, active.thread);
			const lines = [`# Workpackages for ${active.thread}`, ""];
			if (packages.length === 0) lines.push("No open workpackages.");
			else {
				for (const pkg of packages) {
					const marker = active.workpackage && path.resolve(active.workpackage) === path.resolve(pkg.path) ? " ←" : "";
					lines.push(`- **${pkg.id}** — ${pkg.status} — ${pkg.title}${marker}`);
				}
			}
			lines.push("", "Actions:", "- `/agent-os wp <id>` bind a workpackage", "- `/agent-os wp spar <title>` spar and create a draft", "- `/agent-os wp status <id> <state>` transition a workpackage");
			return { output: lines.join("\\n"), binding: undefined };
		}
		return { output: "Usage: /agent-os wp [id|path|clear|delete-all|spar <title>|status <id> <state>]", binding: undefined };
	}
	const statusMatch = value.match(/^status\s+(\S+)\s+(\S+)$/);
	if (value === "status" || statusMatch) {
		if (!active.thread) throw new Error("select a thread before changing workpackage status");
		if (!statusMatch) throw new Error("usage: /agent-os wp status <id> <state>");
		const [, id, status] = statusMatch;
		const current = await resolveWorkpackage(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionWorkpackage(agentos.workspacePath, active.thread, id, status as Parameters<typeof transitionWorkpackage>[3]);
		return { output: `Updated workpackage ${updated.id} to ${updated.status}`, binding: undefined };
	}
	if (value === "delete-all") {
		if (agentos.mode === "Factory") throw new Error("FactoryOS workpackage binding is fixed");
		if (!active.thread) throw new Error("select a thread before deleting workpackages");
		const deleted = await deleteOpenWorkpackages(agentos.workspacePath, active.thread);
		setBinding({ thread: active.thread });
		return {
			output: deleted.length
				? `Deleted ${deleted.length} open workpackage(s) for ${active.thread}`
				: `No open workpackages for ${active.thread}`,
			binding: undefined,
		};
	}
	if (value === "clear") {
		if (agentos.mode === "Factory") {
			throw new Error("FactoryOS workpackage binding is fixed");
		}
		setBinding({ thread: active.thread });
		return { output: "Cleared the active workpackage", binding: undefined };
	}
	if (value === "spar" || value.startsWith("spar ")) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS workpackage binding is fixed");
		if (!active.thread) throw new Error("select a thread before creating a workpackage");
		const created = await createWorkpackage(agentos.workspacePath, active.thread, value.slice(4).trim());
		const relative = workpackageRelativePath(agentos.workspacePath, created.path);
		const binding: AgentOsBinding = {
			version: 1,
			thread: active.thread,
			workpackage: relative,
			project: process.env.AGENT_OS_PROJECT_ROOT ?? process.cwd(),
			workspace: agentos.repoPath ?? undefined,
			scope: agentos.scope ?? undefined,
			profile: process.env.NAX_PROFILE,
			updatedAt: new Date().toISOString(),
		};
		setBinding({ thread: active.thread, workpackage: created.path });
		return {
			output: `Created draft workpackage ${created.id} (${relative}) and bound it for sparring`,
			binding,
		};
	}
	if (!active.thread) throw new Error("select a thread before binding a workpackage");
	if (agentos.mode === "Factory" && agentos.workpackagePath) {
		const current = path.resolve(agentos.workpackagePath);
		const requested = path.resolve(agentos.workspacePath, "threads", active.thread, "workpackages", value);
		const workspaceRequested = path.resolve(agentos.workspacePath, value);
		if (value !== path.basename(current) && path.resolve(value) !== current && requested !== current && workspaceRequested !== current) {
			throw new Error("FactoryOS workpackage binding is fixed");
		}
	}
	const resolved = await resolveWorkpackage(agentos.workspacePath, active.thread,
		agentos.mode === "Factory" && agentos.workpackagePath ? agentos.workpackagePath : value);
	if (agentos.mode === "Factory" && agentos.workpackagePath &&
		resolved.path !== agentos.workpackagePath) {
		throw new Error("FactoryOS workpackage binding is fixed");
	}
	const relative = workpackageRelativePath(agentos.workspacePath, resolved.path);
	const binding: AgentOsBinding = {
		version: 1,
		thread: active.thread,
		workpackage: relative,
		project: process.env.AGENT_OS_PROJECT_ROOT ?? process.cwd(),
		workspace: agentos.repoPath ?? undefined,
		scope: agentos.scope ?? undefined,
		profile: process.env.NAX_PROFILE,
		updatedAt: new Date().toISOString(),
	};
	setBinding({ thread: active.thread, workpackage: resolved.path });
	return { output: `Bound workpackage ${resolved.id} (${relative})`, binding };
}
