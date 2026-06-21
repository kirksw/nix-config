/// <reference path="./types.d.ts" />
/**
 * Thread OS Extension
 *
 * Native Pi bridge to the git-backed Thread OS workspace.
 *
 * Commands:
 *   /thread-os status
 *   /thread-os thread <slug>
 *   /thread-os new-thread <title> --kind <kind>
 *   /thread-os capture [text]
 *   /thread-os focus
 *   /thread-os render
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { handleCapture } from "./commands/capture.js";
import { handleFocus } from "./commands/focus.js";
import { emit } from "./commands/output.js";
import { handleRender } from "./commands/render.js";
import { handleStatus } from "./commands/status.js";
import {
	handleNewThread,
	handleThread,
	handleReconcile,
} from "./commands/thread.js";
import { resolveThreadOsContext } from "./core/repo.js";

const activeThreads = new Map<string, string>();

function splitCommand(args: string): { command: string; rest: string } {
	const trimmed = (args ?? "").trim();
	if (!trimmed) return { command: "status", rest: "" };
	const match = trimmed.match(/^(\S+)(?:\s+([\s\S]*))?$/);
	return { command: match?.[1] ?? "status", rest: match?.[2] ?? "" };
}

function help(): string {
	return [
		"# Thread OS commands",
		"",
		"- `/thread-os status`",
		"- `/thread-os thread <slug>`",
		"- `/thread-os new-thread <title> --kind <idea|research|project|product|concept|ops>`",
		"- `/thread-os capture [text]`",
		"- `/thread-os focus`",
		"- `/thread-os render`",
		"- `/thread-os reconcile [<slug>]`",
	].join("\n");
}

export default function threadOsExtension(pi: ExtensionAPI): void {
	pi.registerCommand("thread-os", {
		description:
			"Manage git-backed Thread OS threads, captures, focus, and markdown views",
		handler: async (args, ctx) => {
			const { command, rest } = splitCommand(args);
			const lifeos = await resolveThreadOsContext(ctx);
			const getActive = (workspacePath: string | null) =>
				workspacePath ? activeThreads.get(workspacePath) : undefined;
			const setActive = (workspacePath: string, slug: string) =>
				activeThreads.set(workspacePath, slug);

			try {
				let output: string;
				switch (command) {
					case "status":
						output = await handleStatus(rest, ctx, lifeos, getActive);
						break;
					case "thread":
						output = await handleThread(rest, lifeos, setActive);
						break;
					case "new-thread":
						output = await handleNewThread(rest, lifeos, setActive);
						break;
					case "capture":
						output = await handleCapture(rest, lifeos, getActive);
						break;
					case "focus":
						output = await handleFocus(rest, lifeos);
						break;
					case "render":
						output = await handleRender(rest, lifeos);
						break;
					case "reconcile":
						output = await handleReconcile(rest, lifeos);
						break;
					case "help":
					case "--help":
					case "-h":
						output = help();
						break;
					default:
						output = `${help()}\n\nUnknown subcommand: ${command}`;
						emit(ctx, output, "warning");
						return;
				}
				emit(ctx, output, "info");
			} catch (err) {
				emit(ctx, `Thread OS error: ${(err as Error).message}`, "error");
			}
		},
	});
}
