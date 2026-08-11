#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const config = process.env.MCPORTER_CONFIG
  ?? resolve(dirname(fileURLToPath(import.meta.url)), "../../../../..", "settings", "mcporter.json");
const [command] = process.argv.slice(2);
const servers = JSON.parse(readFileSync(config, "utf8")).mcpServers ?? {};

if (command !== "status") throw new Error("usage: recruiting.mjs status");
const teamtailor = servers.teamtailor;
console.log(JSON.stringify(teamtailor
  ? { available: true, server: "teamtailor", next: "Use its dedicated commands after authentication." }
  : { available: false, server: "teamtailor", reason: "Teamtailor is disabled in this profile." }, null, 2));
