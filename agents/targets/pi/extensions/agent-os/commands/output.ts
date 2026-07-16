/// <reference path="../types.d.ts" />
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

export function emit(
	pi: ExtensionAPI,
	ctx: ExtensionContext,
	message: string,
	level: "info" | "warning" | "error" = "info",
): void {
	pi.sendMessage({
		customType: "agent-os",
		content: message.replace(/\r?\n$/, ""),
		display: true,
	});
	ctx.ui.notify(message.split(/\r?\n/)[0] || "Agent OS", level);
}
