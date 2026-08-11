#!/usr/bin/env node
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const [tool, ...args] = process.argv.slice(2);
if (!tool) throw new Error("usage: run.mjs <generated-linear-command> [command arguments]");

const writeOperation = /^(create|update|delete|archive|unarchive|add|remove|prepare|upload|set|assign|move|change|link|unlink|subscribe|unsubscribe|resolve|unresolve|start|stop|cancel|merge|approve|reject|invite|revoke)/;
if (writeOperation.test(tool) && process.env.LINEAR_WRITE_CONFIRMED !== "1") {
  throw new Error(`Refusing mutating Linear command '${tool}'. Obtain confirmation, then set LINEAR_WRITE_CONFIRMED=1.`);
}

const cli = resolve(dirname(fileURLToPath(import.meta.url)), "..", "generated", "linear.mjs");
const result = spawnSync("node", [cli, tool, ...args], { encoding: "utf8", timeout: 90_000, maxBuffer: 10 * 1024 * 1024 });
if (result.error) throw result.error;
if (result.status !== 0) throw new Error((result.stderr || result.stdout || `Linear CLI exited ${result.status}`).slice(0, 4_000));

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
