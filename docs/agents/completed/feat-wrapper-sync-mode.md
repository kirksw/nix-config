# feat-wrapper-sync-mode

> Configure nix-agents wrappers to avoid overwriting `sync-agents` output on launch.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The new `sync-agents` app can roll out generated agent assets without sudo, but installed nix-agents wrappers still resync their embedded store generation on each launch. That can undo a manual sync until a full Darwin switch installs a newer wrapper. Upstream wrapper behavior needs a `syncMode` option, and this repo should request `bootstrap` mode.

## Plan

### Scope

- Upstream: nix-agents `lib/core/builders.nix`
- This repo: `modules/home/programs/ai-agents.nix`
- This repo: `flake/apps.nix`
- This repo: docs/agent plan and backlog

### Approach

1. Add upstream `mkWrappedTool.syncMode` with `always` (default), `bootstrap`, and `never` modes.
2. Make bootstrap sync only missing generated paths, preserving `sync-agents` output.
3. Sync wrapper-consumed metadata (`hook-manifest`, `skill-versions.json`) into profiles and prefer profile copies when present.
4. Set this repo's wrapped tools to `syncMode = "bootstrap"` when the upstream input supports it.
5. Update `sync-agents` to sync `hook-manifest` and `skill-versions.json`.
6. Validate upstream and current repo.

### Risks

- Existing installed wrappers still need one Darwin switch before the new behavior is active.
- This repo temporarily tracks the upstream `feat/wrapper-sync-mode` branch until it is merged.

## Testing

Commands run to validate:

```sh
# nix-agents upstream branch
cd /tmp/nix-agents-syncmode && nix flake check --no-build

# nix-config
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
apps/aarch64-darwin/build lunar
nix run .#sync-agents
```

Notes:

- An initial `apps/aarch64-darwin/build` without a hostname failed with usage output; reran successfully as `apps/aarch64-darwin/build lunar`.

## Summary

### What changed

- Added upstream nix-agents `mkWrappedTool.syncMode` support in branch `feat/wrapper-sync-mode` and pushed it.
- Updated this flake to use `github:kirksw/nix-agents/feat/wrapper-sync-mode`.
- Wrapped tools now request `syncMode = "bootstrap"`.
- `sync-agents` now copies `hook-manifest` and `skill-versions.json` into each mutable profile.
- Refined the stale-wrapper note to only apply to pre-syncMode wrappers until the next Darwin switch.

### What was tested

- Upstream nix-agents flake check passed.
- Current repo structure check and flake check passed.
- `sync-agents --dry-run` showed metadata sync.
- `apps/aarch64-darwin/build lunar` completed successfully.
- `nix run .#sync-agents` completed successfully.

### Follow-up

- Run one final Darwin switch to install the syncMode-aware wrappers.
- Merge upstream nix-agents branch and point the input back to the default branch.
