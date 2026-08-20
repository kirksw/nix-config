import assert from "node:assert/strict";
import test from "node:test";

import { analyzeSession, decodeSessionExport, evaluateBudgets } from "./analyze-pi-export.mjs";

function exportHtml(session) {
  const encoded = Buffer.from(JSON.stringify(session), "utf8").toString("base64");
  return `<!doctype html><script id="session-data">${encoded}</script>`;
}

test("decodes and analyzes a Pi session export", () => {
  const session = {
    systemPrompt: [
      "Core guidance",
      "<project_context>",
      "Repository guidance",
      "</project_context>",
      "<available_skills>",
      "  <skill>",
      "    <name>nix-agents</name>",
      "    <description>Nix workflow</description>",
      "    <location>/tmp/SKILL.md</location>",
      "  </skill>",
      "</available_skills>",
    ].join("\n"),
    tools: [
      { name: "read", description: "Read", parameters: { type: "object" } },
      { name: "ctx_search", description: "Search", parameters: { type: "object" } },
      { name: "act", description: "Act", parameters: { type: "object" } },
      { name: "Agent", description: "Delegate", parameters: { type: "object" } },
      { name: "web_search", description: "Research", parameters: { type: "object" } },
      { name: "todo", description: "Track", parameters: { type: "object" } },
      { name: "custom", description: "Other", parameters: { type: "object" } },
    ],
    entries: [
      {
        type: "message",
        message: { role: "assistant", usage: { input: 1234 } },
      },
    ],
  };

  const decoded = decodeSessionExport(exportHtml(session));
  const report = analyzeSession(decoded);

  assert.equal(report.firstInputTokens, 1234);
  assert.equal(report.latestInputTokens, 1234);
  assert.equal(report.skills.count, 1);
  assert.deepEqual(report.skills.names, ["nix-agents"]);
  assert.equal(report.tools.count, 7);
  assert.equal(report.tools.families.builtins.count, 1);
  assert.equal(report.tools.families.contextMode.count, 1);
  assert.equal(report.tools.families.browser.count, 1);
  assert.equal(report.tools.families.subagents.count, 1);
  assert.equal(report.tools.families.web.count, 1);
  assert.equal(report.tools.families.workflow.count, 1);
  assert.equal(report.tools.families.other.count, 1);
  assert.ok(report.systemPrompt.projectContextChars > 0);
  assert.ok(report.systemPrompt.skillCatalogChars > 0);
});

test("reports first and latest assistant input-token measurements", () => {
  const report = analyzeSession({
    systemPrompt: "",
    tools: [],
    entries: [
      { type: "message", message: { role: "assistant", usage: { input: 100 } } },
      { type: "message", message: { role: "user", content: "again" } },
      { type: "message", message: { role: "assistant", usage: { input: 250 } } },
    ],
  });

  assert.equal(report.firstInputTokens, 100);
  assert.equal(report.latestInputTokens, 250);
});

test("reports every exceeded or unavailable budget", () => {
  const report = analyzeSession({ systemPrompt: "large", tools: [], entries: [] });
  const failures = evaluateBudgets(report, {
    "max-input-tokens": 1000,
    "max-system-chars": 2,
    "max-skills": 0,
  });

  assert.deepEqual(failures, [
    "first-turn input tokens: unavailable (limit 1000)",
    "system prompt characters: 5 exceeds 2",
  ]);
});

test("marks prompt and tool metadata unavailable when an export omits it", () => {
  const report = analyzeSession({
    entries: [{ type: "message", message: { role: "assistant", usage: { input: 7999 } } }],
  });

  assert.equal(report.firstInputTokens, 7999);
  assert.equal(report.latestInputTokens, 7999);
  assert.equal(report.systemPrompt.chars, null);
  assert.equal(report.skills.count, null);
  assert.equal(report.tools.count, null);
  assert.deepEqual(evaluateBudgets(report, { "max-system-chars": 18000, "max-tools": 24 }), [
    "system prompt characters: unavailable (limit 18000)",
    "active tools: unavailable (limit 24)",
  ]);
});

test("rejects exports without session data", () => {
  assert.throws(() => decodeSessionExport("<html></html>"), /session-data script/);
});
