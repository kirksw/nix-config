---
name: 1password
description: Use 1Password MCPorter CLI for authenticated environment, variable, and local env-file operations when the user explicitly requests 1Password access.
---

# 1Password

Run the generated `1password` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" 1password list-environments
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" 1password list-variables --help
```

Use command-specific `--help` before supplying unfamiliar flags.
Minimize secret exposure: return names and references unless the user explicitly needs a value, and never include secret values in summaries or logs.
Treat environment, variable, and env-file changes as mutations and follow the confirmation control in the `work-mcp` skill.
Use `authenticate` only when 1Password access is required and the desktop app is available.
