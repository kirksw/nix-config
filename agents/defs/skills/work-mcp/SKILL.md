---
name: work-mcp
description: Use complete generated CLI wrappers for configured work MCP servers without loading direct MCP tools.
---

# Work MCP wrappers

Use this skill's `scripts/run.mjs` runner with the generated CLI artifact in the adjacent `generated/` directory:

```sh
node <this-skill-directory>/scripts/run.mjs <server> <command> [flags]
```

The skill directory is the installed `work-mcp` skill location for the active client profile.
Use the exact path shown by the loaded skill when invoking it from a native shell.

Available generated servers are the `.cjs` files under `generated/`.
Each generated CLI contains the complete MCP tool schema captured at its last refresh.

Examples:

```sh
node <this-skill-directory>/scripts/run.mjs slack slack_search_messages --query "incident" --limit 10
node <this-skill-directory>/scripts/run.mjs lunar-skills list-skills --help
```

For Pi, invoke the runner through `ctx_execute` so Context Mode bounds and summarizes the result before it enters the conversation.
For Claude, Codex, and OpenCode, use their native shell tool and request JSON output when supported.
Do not print raw catalogs or unbounded result sets.

Use `<command> --help` for a command-specific embedded schema; do not use root help unless necessary.
The runner bounds JSON output before it reaches the client.
It blocks mutations unless the user explicitly confirms and the same process sets `MCP_WRITE_CONFIRMED=1`.

Refresh generated wrappers explicitly, never during Nix evaluation or profile sync:

```sh
nix run .#update-mcp-skills
nix run .#sync-agents
```

If refresh reports an authentication error, authenticate the named server with MCPorter and rerun the update command.
