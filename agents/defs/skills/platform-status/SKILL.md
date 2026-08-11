---
name: platform-status
description: Investigate Grafana and Hubble through a bounded Context Mode CLI.
---

# Platform Status

Use `ctx_execute` to run this skill's CLI.
Do not call a direct MCP or print raw telemetry.

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/platform-status/scripts/platform-status.mjs" catalog grafana
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/platform-status/scripts/platform-status.mjs" catalog hubble-mcp
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/platform-status/scripts/platform-status.mjs" call grafana <tool> '<json-args>'
```

`catalog` returns only operation names and parameters.
`call` requires explicit JSON arguments and bounds arrays, object fields, nesting, and strings before output.

Start with the shortest incident window, named service, and specific signal needed.
Report timestamps, scope, evidence, and time zone separately from hypotheses.
Authenticate through Context Mode with `npx --yes mcporter@0.13.3 --config "$MCPORTER_CONFIG" auth <server>` when needed.
