#!/usr/bin/env node

import fs from "node:fs";
import { pathToFileURL } from "node:url";

const TOOL_FAMILIES = {
  builtins: new Set(["read", "bash", "edit", "write", "grep", "find", "ls"]),
  browser: new Set(["act", "see", "state", "run", "vision"]),
  subagents: new Set(["Agent", "get_subagent_result", "steer_subagent"]),
  web: new Set(["web_search", "fetch_content", "get_search_content"]),
  workflow: new Set(["ask_user_question", "todo", "agent_journal", "herdr", "recall"]),
};

function fail(message) {
  throw new Error(message);
}

export function decodeSessionExport(html) {
  const match = html.match(/<script[^>]*\bid=["']session-data["'][^>]*>([\s\S]*?)<\/script>/i);
  if (!match) {
    fail("export does not contain a session-data script");
  }

  let json;
  try {
    json = Buffer.from(match[1].trim(), "base64").toString("utf8");
  } catch (error) {
    fail(`could not decode session-data: ${error.message}`);
  }

  try {
    return JSON.parse(json);
  } catch (error) {
    fail(`session-data is not valid JSON: ${error.message}`);
  }
}

function sliceBetween(text, startMarker, endMarker) {
  const start = text.indexOf(startMarker);
  if (start === -1) return "";
  const end = text.indexOf(endMarker, start + startMarker.length);
  return end === -1 ? text.slice(start) : text.slice(start, end + endMarker.length);
}

function toolFamily(name) {
  if (name.startsWith("ctx_")) return "contextMode";
  for (const [family, names] of Object.entries(TOOL_FAMILIES)) {
    if (names.has(name)) return family;
  }
  return "other";
}

function inputTokenMeasurements(entries) {
  const inputs = entries
    .filter((entry) => entry?.type === "message" && entry.message?.role === "assistant")
    .map((entry) => entry.message.usage?.input)
    .filter(Number.isFinite);
  return {
    first: inputs[0] ?? null,
    latest: inputs.at(-1) ?? null,
  };
}

export function analyzeSession(session) {
  const hasSystemPrompt = typeof session.systemPrompt === "string";
  const hasTools = Array.isArray(session.tools);
  const systemPrompt = hasSystemPrompt ? session.systemPrompt : "";
  const tools = hasTools ? session.tools : [];
  const entries = Array.isArray(session.entries) ? session.entries : [];
  const projectContext = sliceBetween(systemPrompt, "<project_context>", "</project_context>");
  const skillCatalog = sliceBetween(systemPrompt, "<available_skills>", "</available_skills>");
  const coreEnd = [systemPrompt.indexOf("<project_context>"), systemPrompt.indexOf("<available_skills>")]
    .filter((index) => index >= 0)
    .sort((left, right) => left - right)[0] ?? systemPrompt.length;
  const skills = [...skillCatalog.matchAll(/<skill>\s*<name>(.*?)<\/name>[\s\S]*?<\/skill>/g)].map(
    (match) => match[1],
  );

  const toolRows = tools.map((tool) => ({
    name: String(tool?.name ?? "unknown"),
    family: toolFamily(String(tool?.name ?? "unknown")),
    chars: JSON.stringify(tool).length,
  }));
  const toolFamilies = {};
  for (const row of toolRows) {
    const family = (toolFamilies[row.family] ??= { count: 0, chars: 0 });
    family.count += 1;
    family.chars += row.chars;
  }

  const inputTokens = inputTokenMeasurements(entries);
  return {
    firstInputTokens: inputTokens.first,
    latestInputTokens: inputTokens.latest,
    systemPrompt: {
      chars: hasSystemPrompt ? systemPrompt.length : null,
      lines: hasSystemPrompt ? (systemPrompt ? systemPrompt.split("\n").length : 0) : null,
      coreChars: hasSystemPrompt ? systemPrompt.slice(0, coreEnd).length : null,
      projectContextChars: hasSystemPrompt ? projectContext.length : null,
      skillCatalogChars: hasSystemPrompt ? skillCatalog.length : null,
    },
    skills: {
      count: hasSystemPrompt ? skills.length : null,
      names: hasSystemPrompt ? skills : null,
    },
    tools: {
      count: hasTools ? tools.length : null,
      chars: hasTools ? JSON.stringify(tools).length : null,
      families: hasTools ? toolFamilies : null,
      largest: hasTools ? toolRows.sort((left, right) => right.chars - left.chars) : null,
    },
  };
}

const BUDGET_OPTIONS = {
  "max-input-tokens": ["firstInputTokens", "first-turn input tokens"],
  "max-system-chars": ["systemPrompt.chars", "system prompt characters"],
  "max-tool-chars": ["tools.chars", "tool schema characters"],
  "max-skills": ["skills.count", "visible skills"],
  "max-tools": ["tools.count", "active tools"],
};

function valueAt(report, path) {
  return path.split(".").reduce((value, key) => value?.[key], report);
}

export function evaluateBudgets(report, budgets) {
  const failures = [];
  for (const [option, limit] of Object.entries(budgets)) {
    const definition = BUDGET_OPTIONS[option];
    if (!definition) continue;
    const [path, label] = definition;
    const actual = valueAt(report, path);
    if (actual === null || actual === undefined) {
      failures.push(`${label}: unavailable (limit ${limit})`);
    } else if (actual > limit) {
      failures.push(`${label}: ${actual} exceeds ${limit}`);
    }
  }
  return failures;
}

function parseArguments(argv) {
  const args = [...argv];
  const exportPath = args.shift();
  if (!exportPath || exportPath === "-h" || exportPath === "--help") {
    return { help: true };
  }

  const budgets = {};
  let json = false;
  while (args.length > 0) {
    const option = args.shift();
    if (option === "--json") {
      json = true;
      continue;
    }
    const name = option?.replace(/^--/, "");
    if (!BUDGET_OPTIONS[name]) fail(`unknown option: ${option}`);
    const rawLimit = args.shift();
    const limit = Number(rawLimit);
    if (!Number.isInteger(limit) || limit < 0) fail(`${option} requires a non-negative integer`);
    budgets[name] = limit;
  }
  return { exportPath, budgets, json, help: false };
}

function printHelp() {
  console.log(`Usage: node scripts/analyze-pi-export.mjs <export.html> [options]\n\nOptions:\n  --max-input-tokens N\n  --max-system-chars N\n  --max-tool-chars N\n  --max-skills N\n  --max-tools N\n  --json`);
}

function printReport(report) {
  console.log(`First-turn input tokens: ${report.firstInputTokens ?? "unavailable"}`);
  if (report.latestInputTokens !== report.firstInputTokens) {
    console.log(`Latest-turn input tokens: ${report.latestInputTokens ?? "unavailable"}`);
  }
  if (report.systemPrompt.chars === null) {
    console.log("System prompt: unavailable in this export");
    console.log("Skills: unavailable in this export");
  } else {
    console.log(
      `System prompt: ${report.systemPrompt.chars} chars, ${report.systemPrompt.lines} lines ` +
        `(core ${report.systemPrompt.coreChars}, project ${report.systemPrompt.projectContextChars}, skills ${report.systemPrompt.skillCatalogChars})`,
    );
    console.log(`Skills: ${report.skills.count}`);
  }
  if (report.tools.chars === null) {
    console.log("Tools: unavailable in this export");
  } else {
    console.log(`Tools: ${report.tools.count}, ${report.tools.chars} schema chars`);
    for (const [family, values] of Object.entries(report.tools.families).sort()) {
      console.log(`  ${family}: ${values.count} tools, ${values.chars} chars`);
    }
    console.log("Largest tools:");
    for (const tool of report.tools.largest.slice(0, 10)) {
      console.log(`  ${tool.name}: ${tool.chars} chars (${tool.family})`);
    }
  }
}

export function main(argv = process.argv.slice(2)) {
  const options = parseArguments(argv);
  if (options.help) {
    printHelp();
    return 0;
  }

  const session = decodeSessionExport(fs.readFileSync(options.exportPath, "utf8"));
  const report = analyzeSession(session);
  if (options.json) console.log(JSON.stringify(report, null, 2));
  else printReport(report);

  const failures = evaluateBudgets(report, options.budgets);
  if (failures.length > 0) {
    console.error("Budget failures:");
    for (const failure of failures) console.error(`  - ${failure}`);
    return 1;
  }
  return 0;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    process.exitCode = main();
  } catch (error) {
    console.error(`analyze-pi-export: ${error.message}`);
    process.exitCode = 2;
  }
}
