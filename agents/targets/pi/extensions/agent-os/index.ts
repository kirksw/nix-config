/// <reference path="./types.d.ts" />
/**
 * Agent OS Extension
 *
 * Native Pi bridge to the git-backed Agent OS workspace.
 *
 * Commands:
 *   /agent-os status
 *   /agent-os thread <slug>
 *   /agent-os new-thread <title> --kind <kind>
 *   /agent-os capture [text]
 *   /agent-os focus
 *   /agent-os render
 *   /agent-os workpackage (alias: /agent-os wp)
 */

import * as fs from "node:fs/promises";
import * as path from "node:path";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Markdown } from "@earendil-works/pi-tui";
import { handleBlocker } from "./commands/blocker.ts";
import { handleCapture } from "./commands/capture.js";
import { handleFocus } from "./commands/focus.js";
import { emit } from "./commands/output.js";
import { handleRender } from "./commands/render.js";
import { handleStatus } from "./commands/status.js";
import { handleWorkpackage } from "./commands/workpackage.js";
import { handlePromote } from "./commands/promote.ts";
import { handleOutcome } from "./commands/outcome.ts";
import { handleInbox, handleSend, handleAck, pollMailbox } from "./commands/mailbox.js";
import { handleTodo } from "./commands/todo.js";
import {
	handleNewThread,
	handleThread,
	handleReconcile,
} from "./commands/thread.js";
import { pickThread } from "./commands/thread-picker.js";
import { pickWorkpackage } from "./commands/workpackage-picker.js";
import { resolveAgentOsContext } from "./core/repo.js";
import {
	activeThreadFor,
	activeWorkpackageFor,
	bindRestoredThread,
	shouldStartThreadSession,
	restoreBinding,
	type AgentOsBinding,
} from "./core/binding.js";
import { inferMode } from "./core/mode.js";
import { runtimeFilePath } from "./core/runtime.ts";
import { migrateLegacyRuntime } from "./core/runtime-migration.ts";
import { resolveWorkpackage, type WorkpackageRecord } from "./core/workpackage.js";
import { policyPrompt, shellMentionsProtectedWorkspace } from "./core/policy.js";
import { herdrCreateArgs, herdrFactoryRunArgs, herdrRunArgs, rootPaneId } from "./core/herdr-launch.ts";
import { statusWidgetLine } from "./core/status-widget.ts";

const activeThreads = new Map<string, string>();

async function recordLifecycle(
	kind: string,
	ctx: ExtensionContext,
): Promise<void> {
	const agentos = await resolveAgentOsContext(ctx);
	if (!agentos.workspacePath) return;
	const thread = process.env.AGENT_OS_THREAD_ID ?? activeThreads.get(agentos.workspacePath);
	const workpackage = process.env.AGENT_OS_WORKPACKAGE;
	const mode = inferMode(thread, workpackage);
	const file = runtimeFilePath(agentos.workspacePath, "events", {
		mode,
		thread,
		workpackage,
	});
	await fs.mkdir(path.dirname(file), { recursive: true });
	await fs.appendFile(
		file,
		`${JSON.stringify({
			version: 1,
			type: kind,
			at: new Date().toISOString(),
			thread: thread ?? null,
			workpackage: workpackage ?? null,
			project: process.env.AGENT_OS_PROJECT_ROOT ?? ctx.cwd,
			profile: process.env.NAX_PROFILE ?? null,
		})}\n`,
		"utf8",
	);
}

// Display name is "agentOS"; the "agent-os" kebab is only for paths/keys/commands.
function osLabelFor(scope: string | null): string {
	if (scope === "personal") return "lifeOS";
	if (scope === "lunar") return "lunarOS";
	return "?";
}

async function refreshStatus(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
): Promise<void> {
	void pi;
	const agentos = await resolveAgentOsContext(ctx);
	const thread = activeThreadFor(agentos.workspacePath, activeThreads, process.env);
	const workpackage = activeWorkpackageFor(process.env);
	const mode = inferMode(thread, workpackage);
	const unread = agentos.workspacePath
		? await pollMailbox(agentos, { thread, workpackage })
		: 0;
	const osLabel = osLabelFor(agentos.scope);
	const workpackageName = workpackage
		? path.basename(path.resolve(workpackage))
		: undefined;
	ctx.ui.setWidget?.("agent-os", (_tui, theme) => ({
		render: (width) => [theme.fg("muted", statusWidgetLine(
			mode,
			thread,
			workpackageName,
			unread,
			osLabel,
			width,
		))],
		invalidate: () => {},
	}));
}

function splitCommand(args: string): { command: string; rest: string } {
	const trimmed = (args ?? "").trim();
	if (!trimmed) return { command: "status", rest: "" };
	const match = trimmed.match(/^(\S+)(?:\s+([\s\S]*))?$/);
	const command = match?.[1] ?? "status";
	return {
		command: command === "wp" ? "workpackage" : command,
		rest: match?.[2] ?? "",
	};
}

const agentOsSubcommands = [
	["status", "Show the active thread and workspace status"],
	["thread", "Select or switch the active thread"],
	["new-thread", "Create a thread"],
	["capture", "Capture text to the active thread"],
	["blocker", "Add or resolve blockers"],
	["outcome", "Add or transition outcomes"],
	["focus", "Show the current focus"],
	["render", "Render Agent OS markdown"],
	["promote", "Confirm Factory output promotion to wiki"],
	["reconcile", "Reconcile Agent OS state"],
	["workpackage", "List or bind workpackages; spar creates a draft"],
	["wp", "List or bind workpackages (alias)"],
	["inbox", "Show unread mailbox messages"],
	["send", "Send a mailbox message"],
	["ack", "Acknowledge mailbox messages"],
	["todo", "Add, complete, or list routed todos"],
	["help", "Show Agent OS command help"],
] as const;

function addAutocomplete(ctx: ExtensionContext): void {
	let showBareCommandCompletions = false;
	ctx.ui.onTerminalInput?.((data) => {
		if (data === "\t" && /^\/agent-os\s*$/.test(ctx.ui.getEditorText?.() ?? "")) {
			showBareCommandCompletions = true;
		} else if (data !== "\t") {
			showBareCommandCompletions = false;
		}
	});
	ctx.ui.addAutocompleteProvider?.((current) => ({
		triggerCharacters: ["/"],
		async getSuggestions(lines, cursorLine, cursorCol, options) {
			const beforeCursor = (lines[cursorLine] ?? "").slice(0, cursorCol);
			const match = beforeCursor.match(/^\/agent-os(?:\s+(\S*))?$/);
			if (!match) {
				return current.getSuggestions(lines, cursorLine, cursorCol, options);
			}
			const typed = match[1] ?? "";
			if (beforeCursor === "/agent-os" && !showBareCommandCompletions) return null;
			return {
				prefix: beforeCursor,
				items: agentOsSubcommands
					.filter(([name]) => name.startsWith(typed))
					.map(([name, description]) => ({
						value: name,
						label: name,
						description,
					})),
			};
		},
		applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
			const line = lines[cursorLine] ?? "";
			const beforeCursor = line.slice(0, cursorCol);
			const match = beforeCursor.match(/^(\s*)\/agent-os(?:\s+\S*)?$/);
			if (!match) {
				return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
			}
			const value = (item as { value: string }).value;
			const completed = `${match[1]}/agent-os ${value}`;
			const nextLines = [...lines];
			nextLines[cursorLine] = completed + line.slice(cursorCol);
			return {
				lines: nextLines,
				cursorLine,
				cursorCol: completed.length,
			};
		},
		shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
			const beforeCursor = (lines[cursorLine] ?? "").slice(0, cursorCol);
			return (
				/^\/agent-os(?:\s+\S*)?$/.test(beforeCursor) ||
				current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ||
				false
			);
		},
	}));
}

function help(): string {
	return [
		"# Agent OS commands",
		"",
		"- `/agent-os status`",
		"- `/agent-os thread [slug|list]`  (no slug opens an interactive picker)",
		"- `/agent-os new-thread <title> --kind <kind>` (OKF kind vocabulary)",
		"- `/agent-os capture [text]`",
		"- `/agent-os blocker add <text> | resolve <id>`",
		"- `/agent-os outcome add <title> --goal <goal> | set <id> <state>`",
		"- `/agent-os focus`",
		"- `/agent-os render`",
		"- `/agent-os promote <thread> <workpackage>` (confirm Factory output → wiki)",
		"- `/agent-os reconcile [<slug>]`",
		"- `/agent-os workpackage [id|path|clear|delete-all|spar <title>|status <id> <state>]` (alias: `/agent-os wp`)",
		"- `/agent-os inbox`, `/agent-os send`, `/agent-os ack`",
		"- `/agent-os todo add|done|list`",
	].join("\n");
}

function activeBindingFor(workspacePath: string | null): { thread?: string; workpackage?: string } {
	return {
		thread: activeThreadFor(workspacePath, activeThreads, process.env),
		workpackage: activeWorkpackageFor(process.env),
	};
}

function toolPath(ctx: ExtensionContext, input: Record<string, unknown>): string | undefined {
	const value = input.path ?? input.file_path ?? input.cwd;
	return typeof value === "string" ? path.resolve(ctx.cwd, value) : undefined;
}

function isWorkspacePath(agentos: Awaited<ReturnType<typeof resolveAgentOsContext>>, file: string): boolean {
	return Boolean(agentos.policy && agentos.workspacePath && agentos.policy.workspacePath &&
		(path.resolve(file) === path.resolve(agentos.workspacePath) ||
		path.resolve(file).startsWith(`${path.resolve(agentos.workspacePath)}${path.sep}`)));
}

async function canonicalToolPath(file: string, write: boolean): Promise<string> {
	try {
		return await fs.realpath(file);
	} catch {
		if (!write) return file;
		try {
			return path.join(await fs.realpath(path.dirname(file)), path.basename(file));
		} catch {
			return file;
		}
	}
}

async function enforceToolPolicy(event: any, ctx: ExtensionContext): Promise<{ block: true; reason: string } | undefined> {
	const agentos = await resolveAgentOsContext(ctx);
	const policy = agentos.policy;
	if (!policy) return undefined;
	if (event.toolName === "bash") {
		if (shellMentionsProtectedWorkspace(policy, String(event.input?.command ?? ""))) {
			return { block: true, reason: `${policy.role} must use scoped Agent OS paths instead of workspace shell access` };
		}
		return undefined;
	}
	const readTools = new Set(["read", "grep", "find", "ls"]);
	const writeTools = new Set(["write", "edit"]);
	const file = toolPath(ctx, event.input ?? {});
	if (!file) return undefined;
	const write = writeTools.has(event.toolName);
	const canonical = await canonicalToolPath(file, write);
	const lexicalWorkspace = isWorkspacePath(agentos, file);
	const canonicalWorkspace = isWorkspacePath(agentos, canonical);
	if (lexicalWorkspace && !canonicalWorkspace) {
		return { block: true, reason: `${policy.role} cannot follow a workspace path outside the Agent OS workspace: ${file}` };
	}
	if (!canonicalWorkspace) return undefined;
	if (readTools.has(event.toolName) && !policy.canRead(canonical)) {
		return { block: true, reason: `${policy.role} cannot read ${canonical}` };
	}
	if (write && !policy.canWrite(canonical)) {
		return { block: true, reason: `${policy.role} cannot write ${canonical}` };
	}
	return undefined;
}

function bindingData(
	ctx: ExtensionContext,
	agentos: Awaited<ReturnType<typeof resolveAgentOsContext>>,
	binding: { thread?: string; workpackage?: string },
): AgentOsBinding {
	return {
		version: 1,
		thread: binding.thread,
		workpackage: binding.workpackage,
		project: process.env.AGENT_OS_PROJECT_ROOT ?? ctx.cwd,
		workspace: agentos.repoPath ?? undefined,
		scope: agentos.scope ?? undefined,
		profile: process.env.NAX_PROFILE,
		updatedAt: new Date().toISOString(),
	};
}

function appendBinding(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	agentos: Awaited<ReturnType<typeof resolveAgentOsContext>>,
	binding: { thread?: string; workpackage?: string },
): void {
	pi.appendEntry("agent-os-binding", bindingData(ctx, agentos, binding));
}

async function startFactorySession(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	agentos: Awaited<ReturnType<typeof resolveAgentOsContext>>,
	workpackage: WorkpackageRecord,
	_runReportPath: string,
): Promise<void> {
	const project = process.env.AGENT_OS_PROJECT_ROOT ?? agentos.repoPath ?? ctx.cwd;
	if (process.env.HERDR_ENV === "1" && process.env.HERDR_PANE_ID) {
		const label = `factory:${workpackage.thread}:${workpackage.id}`;
		const workspace = await pi.exec("herdr", herdrCreateArgs(project, label), { signal: ctx.signal });
		if (workspace.code !== 0) throw new Error(workspace.stderr.trim() || "Herdr factory workspace creation failed");
		const paneId = rootPaneId(workspace.stdout);
		const launched = await pi.exec("herdr", herdrFactoryRunArgs(paneId, project, workpackage.thread, workpackage.id), { signal: ctx.signal });
		if (launched.code !== 0) throw new Error(launched.stderr.trim() || "Herdr factory launch failed");
		ctx.ui.notify(`Opened Herdr factory for '${workpackage.id}'`, "success");
		return;
	}
	if (!ctx.newSession) throw new Error("Agent OS factory runs require a newer Pi");
	const binding = bindingData(ctx, agentos, { thread: workpackage.thread, workpackage: workpackage.path });
	const result = await ctx.newSession({
		setup: async (sessionManager) => {
			sessionManager.appendCustomEntry("agent-os-binding", binding);
			sessionManager.appendSessionInfo(`agentOS factory: ${workpackage.id}`);
		},
		withSession: async (replacementCtx) => {
			replacementCtx.ui.notify(`Started a new Pi factory session for '${workpackage.id}'`, "success");
		},
	});
	if (result.cancelled) throw new Error("factory run launch was cancelled");
}

async function startThreadSession(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	agentos: Awaited<ReturnType<typeof resolveAgentOsContext>>,
	slug: string,
): Promise<boolean> {
	const project = process.env.AGENT_OS_PROJECT_ROOT ?? agentos.repoPath ?? ctx.cwd;
	if (process.env.HERDR_ENV === "1" && process.env.HERDR_PANE_ID) {
		const label = `thread:${slug}`;
		const workspace = await pi.exec("herdr", herdrCreateArgs(project, label), {
			signal: ctx.signal,
		});
		if (workspace.code !== 0) {
			throw new Error(workspace.stderr.trim() || "Herdr workspace creation failed");
		}
		const paneId = rootPaneId(workspace.stdout);
		const launched = await pi.exec("herdr", herdrRunArgs(paneId, project, slug), {
			signal: ctx.signal,
		});
		if (launched.code !== 0) {
			throw new Error(launched.stderr.trim() || "Herdr thread launch failed");
		}
		ctx.ui.notify(`Opened Herdr workspace for thread '${slug}'`, "success");
		return true;
	}

	if (!ctx.newSession) {
		ctx.ui.notify("Agent OS thread sessions require a newer Pi", "error");
		return false;
	}
	const binding = bindingData(ctx, agentos, { thread: slug });
	const result = await ctx.newSession({
		setup: async (sessionManager) => {
			sessionManager.appendCustomEntry("agent-os-binding", binding);
			sessionManager.appendSessionInfo(`agentOS: ${slug}`);
		},
		withSession: async (replacementCtx) => {
			replacementCtx.ui.notify(`Started a new Pi session for thread '${slug}'`, "success");
		},
	});
	return !result.cancelled;
}

export default function agentOsExtension(pi: ExtensionAPI): void {
	pi.on("before_agent_start", async (event, ctx) => {
		const agentos = await resolveAgentOsContext(ctx);
		if (!agentos.policy || agentos.policy.role === "OS") return undefined;
		return { systemPrompt: `${event.systemPrompt}\\n\\n${policyPrompt(agentos.policy)}` };
	});
	pi.on("tool_call", (event, ctx) => enforceToolPolicy(event, ctx));

	pi.registerMessageRenderer("agent-os", (message) =>
		new Markdown(message.content, 0, 0, getMarkdownTheme()),
	);

	pi.registerCommand("agent-os", {
		description:
			"Manage git-backed Agent OS threads, captures, focus, and markdown views",
		handler: async (args, ctx) => {
			const { command, rest } = splitCommand(args);
			const agentos = await resolveAgentOsContext(ctx);
			const getActive = (workspacePath: string | null) =>
				activeThreadFor(workspacePath, activeThreads, process.env);
			const getBinding = (workspacePath: string | null) => activeBindingFor(workspacePath);
			const setActive = (workspacePath: string, slug: string) =>
				activeThreads.set(workspacePath, slug);
			const setBinding = (binding: { thread?: string; workpackage?: string }) => {
				if (agentos.workspacePath && binding.thread) activeThreads.set(agentos.workspacePath, binding.thread);
				if (binding.thread) process.env.AGENT_OS_THREAD_ID = binding.thread;
				else delete process.env.AGENT_OS_THREAD_ID;
				if (binding.workpackage) process.env.AGENT_OS_WORKPACKAGE = binding.workpackage;
				else delete process.env.AGENT_OS_WORKPACKAGE;
			};

			try {
				let output: string;
				switch (command) {
					case "status":
						output = await handleStatus(rest, ctx, agentos, getBinding);
						break;
					case "thread": {
						const newThreadSession = shouldStartThreadSession(ctx.cwd);
						let slug = rest.trim();
						if (!slug || slug === "list") {
							if (process.env.AGENT_OS_THREAD_ID && !newThreadSession) {
								throw new Error("ThreadOS/FactoryOS bindings are fixed to their selected thread");
							}
							const chosen = await pickThread(ctx, agentos, getActive);
							if (!chosen) return; // picker cancelled
							slug = chosen;
						}
						if (process.env.AGENT_OS_THREAD_ID && !newThreadSession && slug !== process.env.AGENT_OS_THREAD_ID) {
							throw new Error(`binding is fixed to thread '${process.env.AGENT_OS_THREAD_ID}'`);
						}
						if (newThreadSession) {
							// Validate without changing the current OS session. The selected
							// thread is bound only in the new Herdr/Pi session.
							const threadOutput = await handleThread(slug, agentos, () => {});
							if (await startThreadSession(pi, ctx, agentos, slug)) return;
							output = `${threadOutput}\n\nThread session was cancelled.`;
						} else {
							output = await handleThread(slug, agentos, setActive);
							process.env.AGENT_OS_THREAD_ID = slug;
							delete process.env.AGENT_OS_WORKPACKAGE;
							appendBinding(pi, ctx, agentos, { thread: slug });
						}
						break;
					}
					case "new-thread":
						output = await handleNewThread(rest, agentos, setActive);
						break;
					case "capture":
						output = await handleCapture(rest, agentos, getActive);
						break;
					case "blocker":
						output = await handleBlocker(rest, agentos, getActive);
						break;
					case "outcome":
						output = await handleOutcome(rest, agentos);
						break;
					case "focus":
						if (agentos.mode !== "OS") throw new Error(`${agentos.policy?.role} cannot access workspace-wide focus`);
						output = await handleFocus(rest, agentos);
						break;
					case "render":
						if (agentos.mode !== "OS") throw new Error(`${agentos.policy?.role} cannot render workspace-wide views`);
						output = await handleRender(rest, agentos, getBinding(agentos.workspacePath));
						break;
					case "promote":
						output = await handlePromote(rest, agentos, (title, body) => ctx.ui.confirm(title, body));
						break;
					case "reconcile":
						if (agentos.mode !== "OS") throw new Error(`${agentos.policy?.role} cannot reconcile outside its scope`);
						output = await handleReconcile(rest, agentos);
						break;
					case "workpackage": {
						const activeBinding = getBinding(agentos.workspacePath);
						let workpackageArgs = rest;
						if (!rest.trim() && ctx.ui.custom) {
							const choice = await pickWorkpackage(ctx, agentos, activeBinding);
							if (!choice) return;
							workpackageArgs = choice.kind === "create" ? `spar ${choice.value}` : choice.value;
						}
						const result = await handleWorkpackage(workpackageArgs, agentos, activeBinding, setBinding, (workpackage, runReportPath) => startFactorySession(pi, ctx, agentos, workpackage, runReportPath));
						if (result.binding) appendBinding(pi, ctx, agentos, { thread: result.binding.thread, workpackage: result.binding.workpackage });
						else appendBinding(pi, ctx, agentos, { thread: getActive(agentos.workspacePath) });
						output = result.output;
						break;
					}
					case "inbox":
						output = await handleInbox(agentos, getBinding(agentos.workspacePath));
						break;
					case "send":
						output = await handleSend(rest, agentos, getBinding(agentos.workspacePath));
						break;
					case "ack":
						output = await handleAck(rest, agentos, getBinding(agentos.workspacePath));
						break;
					case "todo":
						output = await handleTodo(rest, agentos, getBinding(agentos.workspacePath));
						break;
					case "help":
					case "--help":
					case "-h":
						output = help();
						break;
					default:
						output = `${help()}\n\nUnknown subcommand: ${command}`;
						emit(pi, ctx, output, "warning");
						return;
				}
				emit(pi, ctx, output, "info");
				await refreshStatus(pi, ctx);
			} catch (err) {
				emit(pi, ctx, `Agent OS error: ${(err as Error).message}`, "error");
			}
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		addAutocomplete(ctx);
		try {
			const restored = restoreBinding(ctx.sessionManager.getEntries(), process.env);
			const agentos = await resolveAgentOsContext(ctx);
			if (agentos.workspacePath) {
				const migration = await migrateLegacyRuntime(agentos.workspacePath);
				if (!migration.success) {
					ctx.ui.notify(`legacy Agent OS runtime retained: ${migration.unsupported.join(", ")}`, "warning");
				}
			}
			bindRestoredThread(restored, activeThreads, agentos.workspacePath);
			if (restored?.workpackage && restored.thread && agentos.workspacePath) {
				try {
					process.env.AGENT_OS_WORKPACKAGE = (await resolveWorkpackage(agentos.workspacePath, restored.thread, restored.workpackage)).path;
				} catch {
					delete process.env.AGENT_OS_WORKPACKAGE;
				}
			}
			await recordLifecycle("session_start", ctx);
			await refreshStatus(pi, ctx);
			const binding = activeBindingFor(agentos.workspacePath);
			if (binding.thread) appendBinding(pi, ctx, agentos, binding);
		} catch (err) {
			ctx.ui.notify(`agent-os status unavailable: ${(err as Error).message}`, "warning");
		}
	});
	pi.on("turn_end", async (_event, ctx) => {
		try {
			await recordLifecycle("turn_end", ctx);
			await refreshStatus(pi, ctx);
		} catch {
			// Status and journal writes must never interrupt a turn.
		}
	});
	pi.on("session_switch", async (_event, ctx) => {
		try {
			await recordLifecycle("session_switch", ctx);
			await refreshStatus(pi, ctx);
		} catch {
			// Status rendering must never interrupt a session switch.
		}
	});
	pi.on("session_shutdown", async (_event, ctx) => {
		try {
			await recordLifecycle("session_shutdown", ctx);
		} catch {
			// Shutdown journaling is best effort; the wrapper must still exit.
		}
	});
}
