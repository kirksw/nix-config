# feat-pi-scoped-models

> Remove GPT-5.6 Terra and GPT-5.5 from Pi scoped model lists.

## Status

- [x] Plan
- [x] Implement
- [ ] Test
- [ ] Complete

## Context

The user requested removal from personal and work scoped lists and approved GPT-6 Sol as the replacement work default.

## Plan

### Scope

Change only model defaults in `agents/base-settings.nix`.
Preserve provider registrations, subagent tiers, and existing edits.

### Approach

1. Remove both models from personal and work `enabledModels` and set the work default to `gpt-6-sol`.
2. Evaluate settings for all six bases, check formatting, and inspect the task diff.

### Risks

Generated runtime settings remain unchanged until the configuration is synced.

## Testing

Source assertions passed for both scoped lists and expected defaults.
`nixfmt --check agents/base-settings.nix` and `git diff --check` passed.
Targeted evaluation through `nix eval` and `nix-instantiate` timed out after 20 and 60 seconds, respectively.
Runtime sync and full flake checks were not run.

## Summary

The requested source changes are implemented, with provider registrations and subagent tiers unchanged.
Evaluation and runtime sync remain unverified because Nix evaluation timed out.
