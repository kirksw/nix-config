# feat-pi-experimental-profiles

> Add opt-in personal and work Pi profiles using Herdr-backed subagents.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Test pi-herdr-agents without changing the default profiles.

## Plan

### Scope

Add Pi-only personal-experimental and work-experimental profiles and isolated bases.
Inherit evaluated default profiles and base settings, replacing pi-subagents with pinned pi-herdr-agents 1.5.1.
With user approval, omit rpiv-btw in experimental profiles because both packages register `/btw`.
Use the replacement package's bundled roles and skills.
Keep the local pi-herdr tool, lifecycle hook, model defaults, tiers, permissions, and skills.
Expose explicit selection through pix and the Pi wrapper.
Preserve unrelated working-tree changes.

### Approach

1. Verify package compatibility and profile wiring.
2. Add derived profiles, settings, selection, and authentication wiring.
3. Validate generated profiles and wrappers, then sync declaratively.

### Risks

The replacement requires a running Herdr instance and has a different subagent tool API.
Separate bases isolate package settings and sessions; authentication should reuse the matching default scope only.
Existing installed wrappers require activation before they can select new profiles.

### Definition Of Done

Both experimental profiles inherit their defaults with the approved subagent package replacement and BTW conflict resolution.
Default and non-Pi profiles remain unchanged.
Selection and generated settings checks pass.
Runtime limitations are reported explicitly.

## Testing

- Formatting, structure, and diff checks passed.
- `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link` passed, including repeated sync and a default-auth location transition.
- `python3 scripts/check-pi-experimental-launchers.py` passed for explicit selection, child-directory selection, and pix scope dispatch.
- Both Herdr extensions loaded together in an offline Pi RPC smoke test and registered the subagent command.
- Flake evaluation passed after targeted sync-app evaluation and retry following the recurring invalid agent-source derivation failure.
- Declarative sync completed; live package lists, model defaults, scoped models, and matching authentication links were verified.
- The isolated-fixture parity test is not a live-home settings comparator: existing defaults have mutable UI preferences absent from the fresh experimental bases.
- Initial implementation attempts using fromJSON on store-context strings and whole-profile module copies failed; native settings attributes and explicit profile fields fixed those failures.
- Read-only review confirmed documenting these Nix patterns would have prevented the implementation failures.

## Remaining Runtime Validation

Darwin activation is required to install the new launcher cases and lifecycle hook links.
No authenticated child model call or managed-worktree launch was run.
Project-local agent directories in child worktrees remain an unverified compatibility edge case.
The user must restart Pi after activation.

## Summary

Source implementation, isolated checks, launcher smoke tests, and declarative sync are complete.
Default profiles remain unchanged by this feature.
Activation and live child execution are not claimed as complete.

## Local Context Package Follow-Up

With user approval, both experimental profiles now load `/Users/kisw/git/github.com/kirksw/pi-extensions/main`.
They exclude `context-mode` and `pi-observational-memory`; lean defaults already excluded `context-mode`.
The local package currently exports `pi-context-flow`, and its runtime dependencies are present.
The generated-profile regression check passed, declarative sync succeeded, and live settings confirm both experimental replacements with default packages preserved.
Formatting, structure, and diff checks passed.
Restart experimental sessions to load the new package; context-flow runtime behavior was not tested by this configuration change.
