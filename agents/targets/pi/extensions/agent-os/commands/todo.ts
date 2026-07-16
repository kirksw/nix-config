import type { AgentOsContext } from "../core/repo.js";
import { requireWritable } from "../core/repo.js";
import { addTodo, doneTodo, listTodos, type TodoContext } from "../core/todo.js";
import { inferMode } from "../core/mode.js";

export async function handleTodo(
	args: string,
	agentos: AgentOsContext,
	binding: { thread?: string; task?: string },
): Promise<string> {
	requireWritable(agentos);
	const match = args.trim().match(/^(add|done|list)(?:\s+([\s\S]*))?$/);
	if (!match) throw new Error("usage: /agent-os todo <add|done|list> [text|number]");
	const context: TodoContext = {
		workspacePath: agentos.workspacePath,
		mode: inferMode(binding.thread, binding.task),
		thread: binding.thread,
		task: agentos.taskPath ?? binding.task,
		policy: agentos.policy,
	};
	switch (match[1]) {
		case "add": return addTodo(context, match[2] ?? "");
		case "done": return doneTodo(context, match[2] ?? "");
		default: return listTodos(context);
	}
}
