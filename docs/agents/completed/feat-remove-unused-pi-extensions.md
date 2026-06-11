# feat-remove-unused-pi-extensions

> Remove unused Pi `orch` and `team-dashboard` extensions.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The `orch` and `team-dashboard` Pi extensions are no longer used and should not
be included in synced Pi profiles.

## Plan

### Scope

- `agents/targets/pi/extensions/orch/index.ts`
- `agents/targets/pi/extensions/team-dashboard/index.ts`

### Approach

1. Remove the unused extension source files from the repo.
2. Validate that the repo structure and flake still evaluate.

### Risks

- Existing generated profile copies under `~/.config/nix-agents/...` may remain
  until `sync-agents` or the wrapper sync refreshes the profile.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
find /Users/kisw/.config/nix-agents/pi/bases -path '*/extensions/orch' -o -path '*/extensions/team-dashboard'
```

## Summary

### What changed

- Removed `agents/targets/pi/extensions/orch/index.ts`.
- Removed `agents/targets/pi/extensions/team-dashboard/index.ts`.
- Synced generated agent profiles so local personal/work Pi extension trees no
  longer contain `orch` or `team-dashboard`.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- Verified no generated `extensions/orch` or `extensions/team-dashboard`
  directories remain under `~/.config/nix-agents/pi/bases`.

### Follow-up

- None.
