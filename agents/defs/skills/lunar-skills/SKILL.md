---
name: lunar-skills
description: Use Lunar Skills MCPorter CLI to discover and read Lunar backend engineering practices and their references.
---

# Lunar Skills

Run the generated `lunar-skills` CLI through Context Mode and the shared bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" lunar-skills lunar-skills-list --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" lunar-skills lunar-skills-search --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/work-mcp/scripts/run.mjs" lunar-skills lunar-skills-read --help
```

Search or list to identify the relevant engineering practice, then read that skill before changing affected work code.
Read a referenced document only when the selected practice points to it and the current task needs the detail.
Treat loaded practices as work-repository guidance and report any conflict with repository-local instructions.
