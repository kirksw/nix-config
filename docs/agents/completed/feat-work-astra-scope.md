# feat-work-astra-scope

> Add Astra to scoped models for all work profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The shared work model scope omits GPT-6 Astra.

## Plan

### Scope

Add `gpt-6-astra` to `piWorkModelDefaults.enabledModels` in `agents/base-settings.nix`.
This shared setting covers work, work-full, and work-factory.

### Approach

1. Add the model to the shared list.
2. Validate source formatting, structure, and flake evaluation.
3. Sync declaratively and verify all three work scopes.

### Risks

Model availability still depends on provider access.

### Definition Of Done

All three work scopes include Astra.
Existing defaults and model tiers remain unchanged.
Generated files are updated only through the sync app.

## Testing

- `nixfmt --check agents/base-settings.nix`, `./scripts/check-structure.sh`, and `git diff --check` passed.
- Initial `nix flake check --no-build` encountered an invalid agent-source derivation.
- Targeted `nix eval .#apps.aarch64-darwin.sync-agents.program --raw --show-trace` succeeded, followed by a successful `nix flake check --no-build --option eval-cache false`.
- `nix run .#sync-agents` passed.
- Parsed synced settings for work, work-full, and work-factory and verified Astra is enabled with OpenAI, Terra, and medium defaults unchanged.
- A read-only review confirmed the Nix sequence is observed recovery evidence, not a guaranteed fix or recurrence prevention.
- Sync warns that pre-syncMode wrappers may restore their embedded generation until the next Darwin switch.

## Summary

Added one model entry to the shared work scope and synced through Nix.
Existing defaults and model tiers are unchanged.
Restart agent sessions to load the updated scope.
