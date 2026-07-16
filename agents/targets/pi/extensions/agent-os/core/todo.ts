/// <reference path="../types.d.ts" />
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { AgentOsMode } from "./mode.js";
import type { AgentOsPolicy } from "./policy.js";
import { assertPolicyRead, assertPolicyWrite } from "./policy.ts";

export interface TodoContext {
	workspacePath: string;
	mode: AgentOsMode;
	thread?: string;
	task?: string;
	policy?: AgentOsPolicy | null;
}

async function exists(file: string): Promise<boolean> {
	return Boolean(await fs.stat(file).catch(() => undefined));
}

export async function todoTarget(context: TodoContext): Promise<string> {
	if (context.mode === "OS") {
		return path.join(context.workspacePath, "inbox", "todos.md");
	}
	if (!context.thread) throw new Error("a thread is required for todos");
	if (context.mode === "Factory") {
		if (!context.task) throw new Error("a task is required for Factory todos");
		return context.policy?.taskPath
			? path.join(context.policy.taskPath, "artifacts", "report.md")
			: context.task;
	}
	const threadDir = path.join(context.workspacePath, "threads", context.thread);
	const todos = path.join(threadDir, "todos.md");
	return (await exists(todos)) ? todos : path.join(threadDir, "README.md");
}

function todoLines(text: string): Array<{ line: number; checked: boolean; text: string }> {
	return text.split("\n").flatMap((line, index) => {
		const match = line.match(/^\s*- \[([ xX])\]\s+(.*)$/);
		return match ? [{ line: index, checked: match[1] !== " ", text: match[2] }] : [];
	});
}

async function readTarget(file: string): Promise<string> {
	return fs.readFile(file, "utf8").catch(() => "");
}

async function ensureTarget(file: string): Promise<string> {
	await fs.mkdir(path.dirname(file), { recursive: true });
	const text = await readTarget(file);
	if (text) return text;
	return "---\n---\n\n";
}

export async function addTodo(context: TodoContext, text: string): Promise<string> {
	const value = text.trim();
	if (!value) throw new Error("usage: /agent-os todo add <text>");
	const file = await todoTarget(context);
	if (context.policy) assertPolicyWrite(context.policy, file);
	let body = await ensureTarget(file);
	if (!/^## Todos\s*$/m.test(body)) body = `${body.replace(/\s*$/, "\n\n")}## Todos\n\n`;
	body += `- [ ] ${value}\n`;
	await fs.writeFile(file, body, "utf8");
	return `Added todo to ${file}`;
}

export async function listTodos(context: TodoContext): Promise<string> {
	const file = await todoTarget(context);
	if (context.policy) assertPolicyRead(context.policy, file);
	const lines = todoLines(await readTarget(file));
	return lines.length === 0
		? `# Agent OS todos\n\n- Target: ${file}\n- None`
		: [`# Agent OS todos`, ``, `- Target: ${file}`, ``, ...lines.map((todo, i) => `- ${i + 1}. [${todo.checked ? "x" : " "}] ${todo.text}`)].join("\n");
}

export async function doneTodo(context: TodoContext, selector: string): Promise<string> {
	const value = selector.trim();
	if (!value) throw new Error("usage: /agent-os todo done <number|text>");
	const file = await todoTarget(context);
	if (context.policy) assertPolicyWrite(context.policy, file);
	const body = await readTarget(file);
	const todos = todoLines(body);
	const index = /^\d+$/.test(value) ? Number(value) - 1 : todos.findIndex((todo) => todo.text === value);
	const target = todos[index];
	if (!target) throw new Error(`todo not found: ${value}`);
	const lines = body.split("\n");
	lines[target.line] = lines[target.line]!.replace("[ ]", "[x]").replace("[X]", "[x]");
	await fs.writeFile(file, lines.join("\n"), "utf8");
	return `Completed todo in ${file}: ${target.text}`;
}
