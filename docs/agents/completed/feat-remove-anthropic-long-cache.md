# feat-remove-anthropic-long-cache

> Remove the Pi extension that forces one-hour Anthropic cache TTLs.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user requested complete removal of the extension.
Pi should use its normal cache behavior without this payload override.

## Plan

### Scope

Remove `agents/targets/pi/extensions/anthropic-long-cache/`, including its tests.
Retain the historical implementation record.
Do not change unrelated files or manually edit generated profiles.

### Approach

1. Confirm references and profile synchronization.
2. Delete the extension implementation and tests.
3. Run structure and flake checks, sync profiles, and verify removal.

### Risks

Existing Pi sessions may retain the loaded extension until restarted.
Cache behavior after removal depends on Pi and provider defaults.

## Testing

- Passed: `./scripts/check-structure.sh`.
- Passed: `git diff --check` and review of the deletion diff.
- Passed: no remaining extension name or function references in `agents/`, `flake/`, or `modules/`.
- Blocked: `nix flake check --no-build` fails with `path 'nnga3vc7534k9mbz6q6093b53casb2a2-nix-config-agents-src.drv' is not valid`.
- The same check with `--option eval-cache false` fails with the same error.
- Recovery: `nix eval --option eval-cache false .#apps.aarch64-darwin.sync-agents.program --show-trace` built the missing source derivation.
- Passed after recovery: `nix flake check --no-build --option eval-cache false`.
- Passed: `nix run --option eval-cache false .#sync-agents`.
- Passed: extension directory absent from all six currently generated Pi profiles.
- Serial evaluation alone did not resolve the initial failure; its root cause remains unconfirmed.

## Summary

### What changed

Deleted the extension implementation and its two unit tests.
Historical documentation remains unchanged.

### What was tested

Source removal, structure validation, and diff hygiene passed.
Full Nix validation and synchronization passed after targeted evaluation recovered the source derivation.

### Follow-up

Restart running Pi sessions to unload the extension.
Legacy profile directories outside the current generated profile set were not manually modified.
The sync tool warns that pre-syncMode wrappers may restore their embedded generation until the next Darwin switch.
Read-only review of possible recovery guidance returned no output, so no validated guardrail recommendation was available.
