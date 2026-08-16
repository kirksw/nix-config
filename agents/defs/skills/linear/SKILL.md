---
name: linear
description: Use Linear MCPorter CLI to find, read, create, and update issues, projects, cycles, documents, initiatives, releases, and comments.
---

# Linear

Run the generated `linear` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" linear list-issues --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" linear get-issue --id ENG-123
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" linear search-documentation --help
```

Prefer exact issue identifiers, team, project, assignee, cycle, or a narrow query over broad listings.
Use command-specific `--help` only when a flag is unknown.
Treat save, create, delete, merge, resolve, submit, and attachment operations as mutations and follow the confirmation control in the `work-mcp` skill.
Do not use direct MCP tools or raw MCPorter calls for normal Linear work.
