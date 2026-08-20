# fix-pi-herdr-watch

> Restore the Pi Herdr `watch` action after the Herdr 0.8 command hierarchy change.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The Pi Herdr extension translated `watch` to the removed `herdr wait output` command.
Herdr 0.8 exposes the operation as `herdr pane wait-output` and requires either `--match TEXT` or `--regex PATTERN`.
The registered tool call was valid, so the failure was an extension and CLI compatibility defect rather than user misuse.
Existing skill documentation already showed the correct Herdr 0.8 command.

## Plan

### Scope

- Update `agents/packages/pi-herdr/index.ts`.
- Add a pure command-argument builder and focused regression tests.
- Add the package test command to `agents/packages/pi-herdr/package.json`.

### Approach

1. Build `pane wait-output` arguments in a dependency-free helper.
2. Select `--match` for literal matching or `--regex` for regular-expression matching, never both.
3. Preserve source, line, timeout, and raw options.
4. Exercise both selector modes with Node's built-in test runner.

### Risks

- A future Herdr CLI hierarchy change could require another compatibility update.
- Runtime JSON response compatibility remains covered by normal extension use rather than this argument-only unit test.

## Testing

Commands run to validate:

```sh
npm test --prefix agents/packages/pi-herdr
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
```

## Summary

### What changed

- Added a pure Herdr 0.8 `pane wait-output` argument builder.
- Updated the Pi `watch` action to use one valid literal or regex selector.
- Added focused regression coverage for all forwarded watch options.

### What was tested

- Both Herdr argument tests passed.
- Structure checks and uncached flake evaluation passed.
- Generated agent profiles synchronized successfully.
- A read-only review confirmed that existing skill documentation was already correct and that a compatibility test, rather than more prose, was the appropriate guardrail.

### Follow-up

- No follow-up work is required.
