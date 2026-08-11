---
name: recruiting
description: Check recruiting integration availability through a deterministic Context Mode CLI without exposing candidate data.
---

# Recruiting

Use `ctx_execute` to run this skill's CLI:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/recruiting/scripts/recruiting.mjs" status
```

The current profile reports Teamtailor as disabled.
Do not probe its MCP endpoint, attempt OAuth, or access another client's token cache.

When Teamtailor is explicitly re-enabled, add dedicated read commands before allowing candidate, job, or application queries.
All recruiting mutations require the user’s explicit confirmation.
