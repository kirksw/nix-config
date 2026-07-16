export type AgentOsMode = "OS" | "Thread" | "Factory";

export function inferMode(
	thread: string | undefined,
	workpackage: string | undefined,
): AgentOsMode {
	if (thread && workpackage) return "Factory";
	if (thread) return "Thread";
	return "OS";
}
