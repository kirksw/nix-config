#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const [server, tool, ...args] = process.argv.slice(2);
if (!server || !tool) throw new Error("usage: run.mjs <server> <generated-command> [command arguments]");
if (!/^[a-z0-9-]+$/.test(server)) throw new Error("server must contain only lowercase letters, digits, and hyphens.");
const skillDir = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const cli = resolve(skillDir, "generated", `${server}.cjs`);
const typedClient = resolve(skillDir, "generated", `${server}-client.d.ts`);
if (!existsSync(cli) && !existsSync(typedClient)) throw new Error(`No generated wrapper exists for '${server}'. Run: nix run .#update-home-mcp-skills`);

const normalizedTool = tool.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();
const writeOperation = /(^|[-_])(add|append|approve|archive|assign|cancel|change|copy|create|delete|download|invite|link|make|manage|mark|merge|move|prepare|refresh|reject|remove|rename|resolve|revoke|rm|save|send|set|start|stop|submit|subscribe|triage|unarchive|unlink|unresolve|unsubscribe|update|upload|write)([-_]|$)/;
if (writeOperation.test(normalizedTool) && process.env.MCP_WRITE_CONFIRMED !== "1") {
  throw new Error(`Refusing mutating ${server} command '${tool}'. Obtain confirmation, then set MCP_WRITE_CONFIRMED=1.`);
}

let result;
if (existsSync(cli)) {
  result = spawnSync("node", [cli, tool, ...args], { encoding: "utf8", timeout: 90_000, maxBuffer: 10 * 1024 * 1024 });
} else {
  if (tool === "help") {
    const methods = [...readFileSync(typedClient, "utf8").matchAll(/^\s+([a-z0-9_]+)\(/gm)].map((match) => match[1]);
    console.log(JSON.stringify({ server, mode: "emit-ts", methods }, null, 2));
    process.exit(0);
  }
  if (args.length !== 1) throw new Error(`The emit-ts fallback requires JSON arguments: run.mjs ${server} <method> '<json>'`);
  JSON.parse(args[0]);
  const config = process.env.MCPORTER_CONFIG ?? resolve(skillDir, "../../../..", "settings", "mcporter.json");
  result = spawnSync("npx", ["--yes", "mcporter@0.13.3", "--config", config, "call", `${server}.${tool}`, "--args", args[0], "--output", "json"], { encoding: "utf8", timeout: 90_000, maxBuffer: 10 * 1024 * 1024 });
}
if (result.error) throw result.error;
if (result.status !== 0) throw new Error((result.stderr || result.stdout || `${server} CLI exited ${result.status}`).slice(0, 4_000));

const bound = (value, depth = 0) => {
  if (depth > 5) return "[truncated]";
  if (typeof value === "string") return value.length > 2_000 ? `${value.slice(0, 2_000)}…` : value;
  if (Array.isArray(value)) return value.slice(0, 50).map((item) => bound(item, depth + 1));
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).slice(0, 80).map(([key, item]) => [key, bound(item, depth + 1)]));
  return value;
};

try {
  console.log(JSON.stringify(bound(JSON.parse(result.stdout)), null, 2));
} catch {
  console.log(result.stdout.slice(0, 50_000));
}
