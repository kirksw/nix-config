import type { AgentOsMode } from "./mode.js";

const modeIcons: Record<AgentOsMode, string> = {
	OS: "",
	Thread: "󰭹",
	Factory: "",
};

export function statusWidgetLine(
	mode: AgentOsMode,
	thread: string | undefined,
	workpackage: string | undefined,
	unread: number,
	osLabel: string,
	width: number,
): string {
	const parts = [`${modeIcons[mode]} ${mode}`];
	if (thread) parts.push(`@${thread}`);
	if (workpackage) parts.push(` ${workpackage}`);
	if (unread > 0) parts.push(`󰍡 ${unread}`);
	const right = osLabel;
	const maxLeftWidth = Math.max(0, width - right.length - 1);
	const left = parts.join("  ·  ").slice(0, maxLeftWidth);
	const gap = Math.max(1, width - left.length - right.length);
	return `${left}${" ".repeat(gap)}${right}`;
}
