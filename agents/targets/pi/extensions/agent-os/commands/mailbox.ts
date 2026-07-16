import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { inferMode, type AgentOsMode } from "../core/mode.js";
import {
	ackMessages,
	appendMessage,
	newMessageId,
	unreadMessages,
	type AgentOsMessage,
} from "../core/mailbox.js";

export interface MailboxBinding {
	thread?: string;
	task?: string;
}

function mode(value: string | undefined): AgentOsMode | undefined {
	if (!value) return undefined;
	const normalized = value.toLowerCase();
	if (normalized === "os") return "OS";
	if (normalized === "thread") return "Thread";
	if (normalized === "factory") return "Factory";
	throw new Error("mode must be OS, Thread, or Factory");
}

function options(args: string): { rest: string; to?: AgentOsMode; thread?: string; task?: string; subject?: string } {
	const tokens = args.trim().split(/\s+/).filter(Boolean);
	const rest: string[] = [];
	let to: AgentOsMode | undefined;
	let thread: string | undefined;
	let task: string | undefined;
	let subject: string | undefined;
	for (let i = 0; i < tokens.length; i += 1) {
		const token = tokens[i];
		if (token === "--to" || token === "--thread" || token === "--task" || token === "--subject") {
			const value = tokens[++i];
			if (!value) throw new Error(`${token} requires a value`);
			if (token === "--to") to = mode(value);
			else if (token === "--thread") thread = value;
			else if (token === "--task") task = value;
			else subject = value;
		} else rest.push(token);
	}
	return { rest: rest.join(" "), to, thread, task, subject };
}

function currentMode(binding: MailboxBinding): AgentOsMode {
	return inferMode(binding.thread, binding.task);
}

export async function handleInbox(
	agentos: AgentOsContext,
	binding: MailboxBinding,
): Promise<string> {
	requireWritable(agentos);
	const messages = await unreadMessages(
		agentos.workspacePath,
		currentMode(binding),
		binding.thread,
		binding.task,
	);
	return messages.length === 0
		? "# Agent OS inbox\n\n- No unread messages"
		: [
			"# Agent OS inbox",
			"",
			...messages.flatMap((message) => [
				`## ${message.id}${message.subject ? ` — ${message.subject}` : ""}`,
				`From: ${message.from.mode}${message.from.thread ? `/${message.from.thread}` : ""}${message.from.task ? `/${message.from.task}` : ""}`,
				"",
				message.body,
				"",
			]),
		].join("\n");
}

export async function handleSend(
	args: string,
	agentos: AgentOsContext,
	binding: MailboxBinding,
): Promise<string> {
	requireWritable(agentos);
	const parsed = options(args);
	const from = currentMode(binding);
	const to = parsed.to ?? from;
	if (to === "OS" && (parsed.thread || parsed.task)) throw new Error("OS recipients cannot have thread/task selectors");
	if (to !== "OS" && !parsed.thread) throw new Error("--thread is required for Thread or Factory recipients");
	if (to === "Thread" && parsed.task) throw new Error("Thread recipients cannot have a task selector");
	if (to === "Factory" && !parsed.task) throw new Error("--task is required for Factory recipients");
	if (parsed.task && !parsed.thread) throw new Error("--task requires --thread");
	const body = parsed.rest.trim();
	if (!body) throw new Error("usage: /agent-os send --to <mode> [--thread slug] [--task id] <message>");
	const message: AgentOsMessage = {
		id: newMessageId(),
		createdAt: new Date().toISOString(),
		from: { mode: from, thread: binding.thread, task: binding.task },
		to: { mode: to, thread: parsed.thread, task: parsed.task },
		subject: parsed.subject,
		body,
		status: "unread",
	};
	await appendMessage(agentos.workspacePath, message);
	return `Sent ${message.id} to ${to}${parsed.thread ? `/${parsed.thread}` : ""}${parsed.task ? `/${parsed.task}` : ""}`;
}

export async function handleAck(
	args: string,
	agentos: AgentOsContext,
	binding: MailboxBinding,
): Promise<string> {
	requireWritable(agentos);
	const value = args.trim();
	if (!value) throw new Error("usage: /agent-os ack <message-id|all>");
	const count = await ackMessages(
		agentos.workspacePath,
		value === "all" ? "all" : value.split(","),
		currentMode(binding),
		binding.thread,
		binding.task,
	);
	return `Acknowledged ${count} message${count === 1 ? "" : "s"}`;
}

export async function pollMailbox(
	agentos: AgentOsContext,
	binding: MailboxBinding,
): Promise<number> {
	if (!agentos.workspacePath) return 0;
	return (await unreadMessages(agentos.workspacePath, currentMode(binding), binding.thread, binding.task)).length;
}
