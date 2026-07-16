# feat-agent-os-thread-launch

> Launch OS threads in focused Herdr workspaces without stale-session errors.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`/agent-os thread` on an `*OS` repository called `ctx.newSession()` and then continued using the replaced command context and Pi API. It also changed the current OS binding instead of launching the selected thread in a separate Herdr workspace.

## Plan

### Scope

- `agents/targets/pi/extensions/agent-os/index.ts`
- `agents/targets/pi/extensions/agent-os/core/herdr-launch.ts`
- Agent OS extension types, tests, and README

### Approach

1. Validate thread selection without changing the current OS binding.
2. Create a focused Herdr workspace and launch `agent-os` there when running inside Herdr.
3. Use `withSession` for the non-Herdr replacement-session fallback and never use the old context after replacement.
4. Add command-construction and Herdr response tests.

### Risks

- Herdr must be available in the current process and have a working socket for the workspace path.
- Outside Herdr, the fallback remains a Pi session replacement rather than a separate terminal workspace.

## Testing

```sh
node --experimental-transform-types --import ./agents/packages/pi-subagents/test/support/register-loader.mjs --test agents/targets/pi/extensions/agent-os/tests/*.test.mjs
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/index.ts
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/core/herdr-launch.ts
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Added Herdr workspace creation and root-pane launch for OS thread selection.
- Preserved the current OS binding while validating the selected thread.
- Added `ctx.newSession({ withSession })` handling for safe fallback replacement sessions.
- Added focused Herdr launch tests and updated extension documentation.

### What was tested

- 22 Agent OS tests passed.
- Syntax, structure, flake, and agent-sync checks passed.

### Follow-up

- None.
