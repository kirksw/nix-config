import * as path from "node:path";
import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { assertPolicyWrite } from "../core/policy.ts";
import { readMarkdownData } from "../core/markdown-store.ts";
import {
	createWorkpackage,
	deleteOpenWorkpackages,
	listWorkpackages,
	reportWorkpackageRun,
	resolveWorkpackage,
	runWorkpackage,
	transitionWorkpackage,
	workpackageRelativePath,
} from "../core/workpackage.js";
import type { FactoryRunLauncher } from "../core/workpackage.js";
import type { AgentOsBinding } from "../core/binding.js";
import { latestWorkpackageOutcomes, renderThreadReadme } from "../render/thread-readme.js";

export type ActiveBinding = { thread?: string; workpackage?: string };
export type BindingSetter = (binding: ActiveBinding) => void;

async function refreshThreadReadme(
	agentos: AgentOsContext,
	threadSlug: string,
	activeWorkpackagePath?: string,
): Promise<void> {
	const data = await readMarkdownData(agentos.workspacePath);
	const thread = data.threads.find((item) => item.slug === threadSlug);
	if (!thread) return;
	const workpackages = data.workpackages.filter((workpackage) => workpackage.thread === threadSlug);
	await renderThreadReadme(
		agentos.workspacePath,
		thread,
		data.blockers,
		data.decisions,
		workpackages,
		activeWorkpackagePath,
		await latestWorkpackageOutcomes(workpackages),
	);
}

export async function handleWorkpackage(
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
			lines.push("", "Actions:", "- `/agent-os wp <id>` bind a workpackage", "- `/agent-os wp spar <title>` spar and create a draft", "- `/agent-os wp status <id> <state>` transition a workpackage", "- `/agent-os wp run [id]` launch a factory run", "- `/agent-os wp run-report <id> <success|failure> [note]` report a run", "- `/agent-os wp accept|reject <id>` finish review");
			return { output: lines.join("\\n"), binding: undefined };
		}
		return { output: "Usage: /agent-os wp [id|path|clear|delete-all|spar <title>|run [id]|run-report <id> <success|failure> [note]|accept <id>|reject <id>|status <id> <state>]", binding: undefined };
	}
	const runMatch = value.match(/^run(?:\s+(\S+))?$/);
	if (runMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot start a workpackage run");
		if (!active.thread) throw new Error("select a thread before running a workpackage");
		const input = runMatch[1] ?? active.workpackage;
		if (!input) throw new Error("usage: /agent-os wp run <id>");
		const current = await resolveWorkpackage(agentos.workspacePath, active.thread, input);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const run = await runWorkpackage(agentos.workspacePath, active.thread, input, launchFactoryRun);
		await refreshThreadReadme(agentos, active.thread, active.workpackage);
		return { output: `Started workpackage ${run.workpackage.id}; run report ${workpackageRelativePath(agentos.workspacePath, run.runReportPath)}`, binding: undefined };
	}
	const reportMatch = value.match(/^run-report\s+(\S+)\s+(success|failure)(?:\s+([\s\S]*))?$/);
	if (value === "run-report" || value.startsWith("run-report ") || reportMatch) {
		if (!active.thread) throw new Error("select a thread before reporting a workpackage run");
		if (!reportMatch) throw new Error("usage: /agent-os wp run-report <id> <success|failure> [note]");
		const [, id, outcome, note] = reportMatch;
		if (agentos.mode === "Factory" && agentos.workpackagePath) {
			const selected = await resolveWorkpackage(agentos.workspacePath, active.thread, id);
			if (path.resolve(selected.path) !== path.resolve(agentos.workpackagePath)) throw new Error("FactoryOS workpackage binding is fixed");
		}
		const updated = await reportWorkpackageRun(agentos.workspacePath, active.thread, id, outcome as "success" | "failure", note);
		await refreshThreadReadme(agentos, active.thread, active.workpackage);
		return { output: `Updated workpackage ${updated.id} to review`, binding: undefined };
	}
	const acceptMatch = value.match(/^accept\s+(\S+)$/);
	if (value === "accept" || acceptMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot accept a workpackage");
		if (!active.thread) throw new Error("select a thread before accepting a workpackage");
		if (!acceptMatch) throw new Error("usage: /agent-os wp accept <id>");
		const [, id] = acceptMatch;
		const current = await resolveWorkpackage(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionWorkpackage(agentos.workspacePath, active.thread, id, "done");
		await refreshThreadReadme(agentos, active.thread, active.workpackage);
		return { output: `Accepted workpackage ${updated.id}; status is done`, binding: undefined };
	}
	const rejectMatch = value.match(/^reject\s+(\S+)$/);
	if (value === "reject" || rejectMatch) {
		if (agentos.mode === "Factory") throw new Error("FactoryOS cannot reject a workpackage");
		if (!active.thread) throw new Error("select a thread before rejecting a workpackage");
		if (!rejectMatch) throw new Error("usage: /agent-os wp reject <id>");
		const [, id] = rejectMatch;
		const current = await resolveWorkpackage(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionWorkpackage(agentos.workspacePath, active.thread, id, "failed");
		await refreshThreadReadme(agentos, active.thread, active.workpackage);
		return { output: `Rejected workpackage ${updated.id}; status is failed`, binding: undefined };
	}
	const statusMatch = value.match(/^status\s+(\S+)\s+(\S+)$/);
	if (value === "status" || statusMatch) {
		if (!active.thread) throw new Error("select a thread before changing workpackage status");
		if (!statusMatch) throw new Error("usage: /agent-os wp status <id> <state>");
		const [, id, status] = statusMatch;
		const current = await resolveWorkpackage(agentos.workspacePath, active.thread, id);
		assertPolicyWrite(agentos.policy, current.packagePath);
		const updated = await transitionWorkpackage(agentos.workspacePath, active.thread, id, status as Parameters<typeof transitionWorkpackage>[3]);
		await refreshThreadReadme(agentos, active.thread, active.workpackage);
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
