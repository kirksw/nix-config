# feat-context-mode-mcporter-routing

> Route MCPorter invocations through Context Mode rather than a direct Pi tool.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The previous local Pi `mcporter` tool returned MCP results directly to the model, bypassing Context Mode.
The intended architecture is thin skills that teach agents to use `ctx_execute` for MCPorter CLI calls and to print only bounded, task-specific summaries.

## What changed

- Removed the local `pi-mcporter` package and its direct Pi tool registration from all managed Pi profiles.
- Retained the generated MCPorter configuration and declarative MCP server definitions.
- Updated the work-profile `linear`, `recruiting`, and `platform-status` skills to use `ctx_execute`.
  The skills prescribe `npx --yes mcporter@0.13.3 --config "$MCPORTER_CONFIG"` commands and require parsing or filtering output before `console.log`.
- Kept safety guidance for mutations and isolated MCPorter OAuth credentials.

## Testing

Commands run successfully:

```sh
./scripts/check-structure.sh
git diff --check
git diff --cached --check
nix run .#sync-agents
nix flake check --no-build --option eval-cache false
```

A Context Mode JavaScript execution successfully ran MCPorter against the generated work configuration and printed only the four Lunar Skills tool signatures.
The synced Pi work settings no longer contain the local `pi-mcporter` package.
The generated Linear skill contains the required `ctx_execute` workflow.

## Follow-up

Restart Pi to reload the changed generated skills.
The sync race follow-up remains tracked in [docs/BACKLOG.md](../BACKLOG.md).
