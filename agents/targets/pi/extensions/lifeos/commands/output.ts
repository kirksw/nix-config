/// <reference path="../types.d.ts" />
import type { ExtensionContext } from "@mariozechner/pi-coding-agent";

export function emit(
	ctx: ExtensionContext,
	message: string,
	level: "info" | "warning" | "error" = "info",
): void {
	if (ctx.ui.setEditorText) {
		ctx.ui.setEditorText(message.endsWith("\n") ? message : `${message}\n`);
	}
	ctx.ui.notify(message.split("\n")[0] || "LifeOS", level);
}
