import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event, ctx) => {
    if (!event.toolName.startsWith("mcp__")) return;

    const annotations = pi.getAllTools().find((tool) => tool.name === event.toolName)?.annotations;
    // Unannotated tools are not assumed read-only.
    if (annotations?.readOnlyHint === true && annotations?.destructiveHint !== true) return;

    if (!ctx.hasUI) {
      return { block: true, reason: `Approval required for ${event.toolName} (no interactive UI)` };
    }
    const approved = await ctx.ui.confirm(
      "Allow work MCP call?",
      event.toolName.startsWith("mcp__1password__")
        ? `${event.toolName}\nArguments hidden to avoid exposing secrets in the approval dialog.`
        : `${event.toolName}\n${JSON.stringify(event.input, null, 2)}`,
    );
    if (!approved) return { block: true, reason: `${event.toolName} was not approved` };
  });
}
