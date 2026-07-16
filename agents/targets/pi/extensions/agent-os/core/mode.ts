export type AgentOsMode = "OS" | "Thread" | "Factory";

export function inferMode(
	thread: string | undefined,
	task: string | undefined,
): AgentOsMode {
	if (thread && task) return "Factory";
	if (thread) return "Thread";
	return "OS";
}
