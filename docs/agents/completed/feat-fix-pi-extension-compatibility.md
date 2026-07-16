# feat-fix-pi-extension-compatibility

> Restore Pi extension compatibility after the `ui.custom()` API changed and refresh the local pi-subagents package snapshot.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`/agent-os thread` passes a component instance to `ctx.ui.custom()`, but Pi 0.80.6 requires a component factory and resolves a result promise. The existing code therefore crashes with `TypeError: factory is not a function`.

The active Nix-generated Pi profile omitted `src/intercom/result-intercom.ts` and `src/runs/background/result-watcher.ts` because the repository-wide `result-*` ignore rule hid both required source files from the flake snapshot.

## Plan

### Scope

- `agents/targets/pi/extensions/agent-os/commands/thread-picker.ts`
- `agents/targets/pi/extensions/agent-os/types.d.ts`
- `agents/targets/pi/extensions/agent-os/index.ts`
- `agents/packages/pi-subagents/src/intercom/result-intercom.ts`
- `agents/packages/pi-subagents/src/runs/background/result-watcher.ts`
- Generated Pi profile assets via `sync-agents`

### Approach

1. Replace the obsolete component/handle interaction with Pi's factory/result-promise API.
2. Retain picker redraw behavior through the injected TUI instance and preserve Theme method binding.
3. Add `/agent-os` subcommand autocomplete through Pi's autocomplete-provider API.
4. Force-track the ignored pi-subagents runtime modules so Nix includes them in the flake source snapshot.
5. Regenerate profile assets and start Pi in a Herdr pane.

### Risks

- The agent-os extension is currently uncommitted; only the picker and its type shim will be changed.
- Nix flake snapshots include tracked files only. The new picker and both ignored pi-subagents runtime modules must be staged before syncing.

## Testing

Commands run to validate:

```sh
node --experimental-strip-types --check agents/targets/pi/extensions/agent-os/commands/thread-picker.ts
node --experimental-strip-types --test agents/targets/pi/extensions/agent-os/tests/binding.test.mjs
(cd agents/packages/pi-subagents && npm test)
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
pi --help
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Migrated the agent-os thread picker to Pi's factory/result-promise `ui.custom()` API, injected redraw support, and preserved Theme method binding.
- Added Tab completion for agent-os subcommands.
- Force-tracked `result-intercom.ts` and `result-watcher.ts`, which the repository-wide `result-*` rule had excluded from Nix flake snapshots.
- Regenerated live agent profiles from the corrected local `pi-subagents` source.

### What was tested

- Picker syntax check and agent-os binding tests passed (3/3).
- Structure checks, `nix flake check --no-build`, sync dry-run, and live sync passed.
- Live profile contains the migrated picker and both required pi-subagents runtime modules.
- A third `pi` launch in Herdr pane `w2:p1Z` reached the interactive startup screen with pi-subagents loaded; the first two launches reproduced each missing ignored module.
- `pi --no-session '/agent-os thread'` in Herdr pane `w2:p10` rendered the picker without crashing.
- In Herdr pane `w2:p21`, Tab completion preserved the single command slash; Down/Enter selected and executed `/agent-os status` successfully.
- In Herdr pane `w2:p25`, typing bare `/agent-os` displayed no menu, and the first Tab displayed all eight subcommands.
- In Herdr pane `w2:p28`, `/agent` then Tab completed the initial command; a second Tab after Pi inserted its trailing space displayed all eight subcommands.
- `pi-subagents` unit tests: 1,069 passed and 14 failed in unrelated existing suites.

### Follow-up

- Added a backlog item to diagnose and repair the unrelated pi-subagents test failures.
