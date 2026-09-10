# feat-pi-default-plannotator

> Add Plannotator to the default work and personal Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user approved adding unpinned `npm:@plannotator/pi-extension` to `work-default` and `personal-default` only.
Browser and fallback profiles must remain unchanged.

## Plan

### Scope

Update the default-profile package transformation in `agents/base-settings.nix`.
Preserve existing uncommitted Bedrock changes.

### Approach

1. Append the package in the transformation used only by the two default profiles.
2. Evaluate package membership across every Pi base, run repository checks, and sync profiles.
3. Verify live settings and record results.

### Risks

The approved unpinned package can change on future package updates.
Sync updates settings; extension installation and loading occur on Pi startup.

## Testing

- `nixfmt --check agents/base-settings.nix`, `git diff --check`, and `./scripts/check-structure.sh` passed.
- Direct Nix evaluation and Python assertions verified exactly one package entry in each default profile and no entry in the other four Pi bases.
- `nix eval --raw .#apps.aarch64-darwin.sync-agents.program --option eval-cache false` passed.
- `nix flake check --no-build --option eval-cache false` passed.
- `nix run .#sync-agents --option eval-cache false` passed.
- Read-only assertions verified the same package scope in all six live base settings files.
- Logs: `/tmp/plannotator-flake-check.log` and `/tmp/plannotator-sync.log`.
- Interactive extension installation and loading were not tested.

## Summary

Added unpinned `npm:@plannotator/pi-extension` to the shared transformation used by personal-default and work-default only.
Browser and fallback package lists are unchanged.
Generated settings are synced; restart affected Pi sessions to install and load the package.
The sync tool warns that old pre-syncMode wrappers can restore embedded settings until the already-tracked Darwin switch.
No additional implementation follow-up remains.
