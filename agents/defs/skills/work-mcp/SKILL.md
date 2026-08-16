---
name: work-mcp
description: Shared MCPorter runner, authentication, output-bounding, regeneration, and mutation controls for dedicated work-tool skills.
---

# Work MCP infrastructure

Tool-named skills provide discovery and operational guidance for each generated MCPorter CLI.
Use this skill for shared runner behavior, authentication, wrapper refreshes, and mutation controls; do not use it as a generic tool router when a dedicated skill exists.

Invoke a generated wrapper through Context Mode:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" <server> <command> [flags]
```

Available servers are the `.cjs` wrappers and typed-client metadata under `generated/`.
Use `<command> --help` for one bundled command’s schema rather than root help.
For a typed-client fallback such as Grafana, use `help` to list methods and pass one JSON object argument to a method.
Do not print raw catalogs or unbounded results.

The runner bounds JSON output and blocks commands that look mutating unless the user explicitly confirms the exact action.
After confirmation, set `MCP_WRITE_CONFIRMED=1` only for that runner process.

Authenticate a server when its dedicated skill reports an authentication failure:

```sh
npx --yes mcporter@0.13.3 --config "$MCPORTER_CONFIG" auth <server>
```

Refresh wrappers explicitly, never during Nix evaluation or profile synchronization:

```sh
nix run .#update-mcp-skills
nix run .#sync-agents
```
