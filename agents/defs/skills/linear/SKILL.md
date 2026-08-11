---
name: linear
description: Use the complete, generated Linear MCP CLI through Context Mode.
---

# Linear

`generated/linear.mjs` is a complete MCPorter-generated CLI for the Linear server.
It embeds the Linear server definition and every tool schema that was available when generated.
It is not a hand-written subset.

Use `ctx_execute` and invoke the bounded runner:

```sh
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/linear/scripts/run.mjs" list-issues --help
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/linear/scripts/run.mjs" list-issues --query "authentication"
node "$HOME/.config/nix-agents/pi/bases/work/profiles/work-default/skills/linear/scripts/run.mjs" get-issue --id ENG-123
```

`run.mjs` forwards every generated command and its flags, bounds JSON before printing it, and blocks mutations unless the user has explicitly confirmed them.
After confirmation, use `LINEAR_WRITE_CONFIRMED=1` only for that `ctx_execute` process.

Do not use a direct MCP tool, `mcporter list linear`, or manually construct a raw MCP call for normal work.
Use `<command> --help` only when a command flag is unknown; it returns that command's embedded schema without contacting Linear.

## Regeneration

Regenerate only when a Linear schema refresh is required:

```sh
npx --yes mcporter@0.13.3 --config "$HOME/.config/nix-agents/pi/bases/work/settings/mcporter.json" \
  generate-cli linear --runtime node \
  --bundle agents/defs/skills/linear/generated/linear.mjs --minify
```

Validate the artifact metadata without contacting Linear:

```sh
node agents/defs/skills/linear/generated/linear.mjs __mcporter_inspect
```
