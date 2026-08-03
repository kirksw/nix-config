# feat-pi-telegram

> Add the Telegram Pi extension to personal interactive profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi needs the external Telegram integration for personal interactive use. The package should be
managed with the existing base package references without changing factory profiles.

## Plan

### Scope

- `agents/base-settings.nix` -- add the pinned Telegram package to `piPackageRefs` only.
- `docs/agents/feat-pi-telegram.md` -- record the feature plan and validation.

### Approach

1. Add `npm:@llblab/pi-telegram@0.26.16` to `piPackageRefs`.
2. Leave `piFactoryPackageRefs` unchanged because Telegram is a personal integration.
3. Validate the source diff and Nix configuration checks without syncing or deploying.

### Risks

- Pi may need network access and Telegram credentials when the package is first used.
- Factory profiles must remain Telegram-free; accidentally adding the package there would broaden
  the integration beyond the requested scope.

### Definition of Done

- The exact pinned package appears in `piPackageRefs`.
- The package does not appear in `piFactoryPackageRefs`.
- No repository-generated files are changed.
- Structure validation and agent-config sync complete successfully.

## Testing

Commands run:

```sh
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache  # fails in unrelated pre-existing flake checks
nix run .#sync-agents
```

The structure check and sync passed. The full flake check still reports an invalid generated
`.drv` path in `apps.aarch64-darwin.sync-agents` and `checks.aarch64-darwin.agentic-factory-profiles`;
this is outside the package-reference change.

## Summary

### What changed

- Added `npm:@llblab/pi-telegram@0.26.16` to personal/work base package references.
- Added this feature plan and completion record.

### What was tested

- `./scripts/check-structure.sh` passed.
- `nix run .#sync-agents` passed and installed the updated settings.
- Confirmed `piFactoryPackageRefs` remains unchanged.
- Full flake check was attempted; it hit the unrelated invalid `.drv` path noted above.

### Follow-up

- None for this feature.
