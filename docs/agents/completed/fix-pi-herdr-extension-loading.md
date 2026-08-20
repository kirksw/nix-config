# fix-pi-herdr-extension-loading

> Restore `pi-herdr` loading from synchronized Nix flake sources and add a store-snapshot smoke check.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The work profile reports that `pi-herdr/index.ts` cannot load `./cli-args.js`.
The helper and its checkout-only unit test are untracked, so Nix flake source snapshots omit them while the tracked entry point imports them.
The checkout test imports the helper directly and therefore passed without loading the synchronized extension entry point.
Pi loads TypeScript extensions through Jiti, and the user-facing failure occurs before tool registration.

## Plan

### Scope

- Update `agents/packages/pi-herdr/index.ts` and `package.json`.
- Remove the untracked helper and checkout-only test.
- Add a Pi RPC extension-load check to `flake.nix` using the flake/store snapshot.
- Synchronize generated profiles and verify the synchronized work-profile source.

### Approach

1. Inline the small watch-argument builder in the tracked extension entry point so the flake snapshot is self-contained.
2. Remove the obsolete helper import, helper file, unit test, and package test script.
3. Add a flake check that starts Pi in RPC mode with no default extensions and explicitly loads `${./agents/packages/pi-herdr/index.ts}` from the flake snapshot without making a model request.
4. Reproduce the old store-source failure, build the new smoke check, synchronize profiles, and load the synchronized work-profile extension through Pi RPC.

### Risks

- The argument builder loses isolated unit coverage, but the stronger flake check validates the actual model-facing extension module graph.
- The smoke check intentionally leaves Herdr environment variables unset, so it validates extension loading rather than live pane operations.
- Existing sessions and old store paths remain broken until profiles are synchronized and Pi is restarted.

## Testing

Commands run to validate:

```sh
nix build .#checks.aarch64-darwin.pi-herdr-extension-load --no-link
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
```

## Summary

### What changed

- Inlined the Herdr watch-argument builder in the tracked extension entry point.
- Removed the missing helper import, the untracked helper and unit test, and the obsolete package test script.
- Added `checks.aarch64-darwin.pi-herdr-extension-load`, which loads the flake-snapshot extension through Pi RPC without a model request.
- Synchronized all profiles to a self-contained `pi-herdr` store source.

### What was tested

- Reproduced the previous synchronized store-source failure with exit status 1 and `Cannot find module './cli-args.js'`.
- Built the new extension-load flake check successfully.
- Loaded the newly synchronized work-profile extension through Pi RPC with exit status 0 and a successful `get_state` response.
- Confirmed the synchronized package has neither the helper import nor the removed Herdr skill.
- Diff, structure, and uncached flake-evaluation checks passed.

### Follow-up

- No follow-up work is required for this loading defect.
