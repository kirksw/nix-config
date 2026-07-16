/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { AgentOsMode } from "./mode.js";
import { normalizeTaskId, runtimeFilePath } from "./runtime.ts";

export interface AgentOsMessage {
	id: string;
	createdAt: string;
	from: { mode: AgentOsMode; thread?: string; task?: string };
	to: { mode: AgentOsMode; thread?: string; task?: string };
	subject?: string;
	body: string;
	status?: "unread" | "acked";
	ackedAt?: string;
}

export function mailboxPath(
	workspacePath: string,
	mode: AgentOsMode,
	thread?: string,
	task?: string,
): string {
	return runtimeFilePath(workspacePath, "mailbox", { mode, thread, task });
}

export async function readMessages(file: string): Promise<AgentOsMessage[]> {
	const body = await fs.readFile(file, "utf8").catch(() => "");
	return body.split("\n").flatMap((line) => {
		if (!line.trim()) return [];
		try {
			const message = JSON.parse(line) as AgentOsMessage;
			return message.id && message.body && message.from && message.to ? [message] : [];
		} catch {
			return [];
		}
	});
}

function matchesActiveScope(
	message: AgentOsMessage,
	mode: AgentOsMode,
	thread?: string,
	task?: string,
): boolean {
	return (
		message.to.mode === mode &&
		(mode === "OS" || message.to.thread === thread) &&
		(mode !== "Factory" ||
			(Boolean(task) &&
				normalizeTaskId(message.to.task) === normalizeTaskId(task)))
	);
}

export async function unreadMessages(
	workspacePath: string,
	mode: AgentOsMode,
	thread?: string,
	task?: string,
): Promise<AgentOsMessage[]> {
	const messages = await readMessages(mailboxPath(workspacePath, mode, thread, task));
	return messages.filter(
		(message) => message.status !== "acked" && matchesActiveScope(message, mode, thread, task),
	);
}

export async function appendMessage(
	workspacePath: string,
	message: AgentOsMessage,
): Promise<void> {
	const file = mailboxPath(workspacePath, message.to.mode, message.to.thread, message.to.task);
	await fs.mkdir(path.dirname(file), { recursive: true });
	await fs.appendFile(file, `${JSON.stringify(message)}\n`, "utf8");
}

export async function ackMessages(
	workspacePath: string,
	ids: string[] | "all",
	mode: AgentOsMode,
	thread?: string,
	task?: string,
): Promise<number> {
	const file = mailboxPath(workspacePath, mode, thread, task);
	const messages = await readMessages(file);
	const selected = new Set(ids === "all" ? [] : ids);
	let count = 0;
	const now = new Date().toISOString();
	for (const message of messages) {
		if (
			message.status !== "acked" &&
			matchesActiveScope(message, mode, thread, task) &&
			(ids === "all" || selected.has(message.id))
		) {
			message.status = "acked";
			message.ackedAt = now;
			count += 1;
		}
	}
	if (messages.length > 0) {
		await fs.mkdir(path.dirname(file), { recursive: true });
		await fs.writeFile(file, `${messages.map((message) => JSON.stringify(message)).join("\n")}\n`, "utf8");
	}
	return count;
}

export function newMessageId(): string {
	return `msg_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 8)}`;
}
