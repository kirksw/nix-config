# feat-mcporter-migration

> Route managed Pi MCP access through one mcporter tool to reduce direct MCP tool context.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Direct Pi MCP tools bypass context-mode and can consume excessive conversation context.
The migration covers all managed Pi profiles and exposes MCP access through one mcporter tool.

## Scope

- Managed Pi package and profile configuration under `agents/`.
- Pi MCP server definitions and the agent-sync workflow.
- Thin work-profile skills for Linear, recruiting, and platform-status queries.
- Generated Pi profile validation after synchronization.

## What changed

- Added the local `pi-mcporter` Pi extension with one `mcporter` tool.
  The tool runs `mcporter@0.13.3` through `npx`, accepts list, call, login, and logout actions, and truncates output using Pi utilities.
- Replaced direct `pi-mcp-adapter` package exposure in all Pi profiles with the local extension.
- Generated per-base `mcporter.json` files from the existing declarative work MCP definitions.
  MCPorter maps the former lazy lifecycle to its ephemeral lifecycle.
- Retained the generated work `mcp.json` only as the declarative source and stale-entry cleanup target; Pi no longer loads it through an MCP adapter.
- Added thin `linear`, `recruiting`, and `platform-status` skills to the work profile.
  They guide small, evidence-oriented mcporter queries and require confirmation before mutations.
- Removed the disabled Teamtailor server from the active configuration.

## Testing

Commands run successfully:

```sh
./scripts/check-structure.sh
git diff --check
git diff --cached --check
nix run .#sync-agents
nix flake check --no-build --option eval-cache false
npx --yes mcporter@0.13.3 --config "$HOME/.config/nix-agents/pi/bases/work/settings/mcporter.json" list lunar-skills
```

The generated work profile contains the three thin skills.
MCPorter listed all four `lunar-skills` tools successfully.
A headless Pi RPC startup completed without extension-load errors.
Restarting Pi is required for active sessions to load the new tool and skills.
OAuth-backed servers such as Linear, Grafana, Hubble, Granola, and Sourcegraph require login through mcporter's separate credential store.

## Follow-up

- [docs/BACKLOG.md](../BACKLOG.md) tracks the generated-profile synchronization race observed while Codex or a wrapper writes the same profile directory.
