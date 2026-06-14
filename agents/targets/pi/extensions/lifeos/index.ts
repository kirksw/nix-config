/// <reference path="./types.d.ts" />
/**
 * LifeOS Extension
 *
 * Native Pi bridge to the git-backed LifeOS workspace.
 *
 * Commands:
 *   /lifeos status
 *   /lifeos thread <slug>
 *   /lifeos new-thread <title> --kind <kind>
 *   /lifeos capture [text]
 *   /lifeos focus
 *   /lifeos render
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { handleCapture } from "./commands/capture.js";
import { handleFocus } from "./commands/focus.js";
import { emit } from "./commands/output.js";
import { handleRender } from "./commands/render.js";
import { handleStatus } from "./commands/status.js";
import { handleNewThread, handleThread } from "./commands/thread.js";
import { resolveLifeOsContext } from "./core/repo.js";

const activeThreads = new Map<string, string>();

function splitCommand(args: string): { command: string; rest: string } {
  const trimmed = (args ?? "").trim();
  if (!trimmed) return { command: "status", rest: "" };
  const match = trimmed.match(/^(\S+)(?:\s+([\s\S]*))?$/);
  return { command: match?.[1] ?? "status", rest: match?.[2] ?? "" };
}

function help(): string {
  return [
    "# LifeOS commands",
    "",
    "- `/lifeos status`",
    "- `/lifeos thread <slug>`",
    "- `/lifeos new-thread <title> --kind <idea|research|project|product|concept|ops>`",
    "- `/lifeos capture [text]`",
    "- `/lifeos focus`",
    "- `/lifeos render`",
  ].join("\n");
}

export default function lifeosExtension(pi: ExtensionAPI): void {
  pi.registerCommand("lifeos", {
    description: "Manage git-backed LifeOS threads, captures, focus, and markdown views",
    handler: async (args, ctx) => {
      const { command, rest } = splitCommand(args);
      const lifeos = await resolveLifeOsContext(ctx);
      const getActive = (workspacePath: string | null) => (workspacePath ? activeThreads.get(workspacePath) : undefined);
      const setActive = (workspacePath: string, slug: string) => activeThreads.set(workspacePath, slug);

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
        emit(ctx, `LifeOS error: ${(err as Error).message}`, "error");
      }
    },
  });
}
