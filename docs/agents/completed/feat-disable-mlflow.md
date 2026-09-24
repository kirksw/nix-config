# Disable MLflow Extension

> Remove MLflow tracing from every Pi profile.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user requested disabling the MLflow extension for all profiles.

## Plan

### Scope

Change the shared package list in `agents/base-settings.nix`.

### Approach

1. Remove the MLflow package reference and its unused local binding.
2. Validate profile settings and repository checks.
3. Sync profile configuration and record results.

### Principles and Risks

The user approved preserving the tracer package, environment settings, and existing uncommitted changes.
Active sessions may require restart to unload the extension.

## Testing

- `nix-instantiate --parse agents/base-settings.nix`: passed.
- `./scripts/check-structure.sh`: passed.
- `nix flake check --no-build`: passed.
- Evaluated all six base package lists: MLflow absent.
- `nix run .#sync-agents`: reported completion.
- Verified synced settings for all six current bases and profiles: MLflow absent.
- `git diff --check`: passed.

An initial evaluation probe required discarding Nix string context before parsing generated JSON.
A broad scan also found obsolete generated base directories, including `work-full`, that are outside the current profile inventory.
These generated files were not edited.

## Summary

Removed the shared MLflow package reference and unused binding.
Preserved the tracer package, environment settings, and existing user changes.
All current profiles are synced without MLflow.
Restart active agent sessions to unload the extension.
The sync tool warns that pre-syncMode wrappers may restore embedded settings until the next Darwin switch.
No implementation follow-up remains.
