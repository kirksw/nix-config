#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const config = process.env.MCPORTER_CONFIG
  ?? resolve(dirname(fileURLToPath(import.meta.url)), "../../../../..", "settings", "mcporter.json");
const [command, server, tool, argsJson = "{}"] = process.argv.slice(2);
if (!new Set(["grafana", "hubble-mcp"]).has(server)) throw new Error("server must be grafana or hubble-mcp.");
const execute = (args) => execFileSync(
  "npx",
  ["--yes", "mcporter@0.13.3", "--config", config, ...args],
  { encoding: "utf8", timeout: 90_000 },
);
const bounded = (value, depth = 0) => {
  if (depth > 4) return "[truncated]";
  if (typeof value === "string") return value.length > 800 ? `${value.slice(0, 800)}…` : value;
  if (Array.isArray(value)) return value.slice(0, 25).map((item) => bounded(item, depth + 1));
  if (value && typeof value === "object") return Object.fromEntries(Object.entries(value).slice(0, 40).map(([key, item]) => [key, bounded(item, depth + 1)]));
  return value;
};

if (command === "catalog") {
  const output = execute(["list", server]);
  const functions = [...output.matchAll(/function ([^(]+)\(([^)]*)\);/g)].map(([, name, params]) => ({ name, params }));
  console.log(JSON.stringify({ server, operations: functions.slice(0, 100) }, null, 2));
} else if (command === "call") {
  if (!tool) throw new Error("usage: platform-status.mjs call <grafana|hubble-mcp> <tool> '<json-args>'");
  const args = JSON.parse(argsJson);
  const output = execute(["call", `${server}.${tool}`, "--args", JSON.stringify(args), "--output", "json"]);
  console.log(JSON.stringify(bounded(JSON.parse(output)), null, 2));
} else {
  throw new Error("usage: platform-status.mjs <catalog|call> <grafana|hubble-mcp> [tool] [json-args]");
}
