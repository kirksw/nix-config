# feat-literal-communication-policy

> Add the user's literal-language policy to shared agent instructions.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user wants a communication policy that favors direct statements over ornamental metaphors.
The user approved preserving the supplied paragraph verbatim in `agents/AGENTS.md` under Communication, with one sentence per line.

## Plan

### Scope

Change shared agent instructions only; do not introduce an extension or modify generated profiles.
Preserve unrelated changes and existing communication rules.

### Approach

1. Record the approved wording and scope.
2. Add the supplied paragraph under Communication.
3. Validate the exact wording, structure, and Nix evaluation; complete this record.

### Risks

The shared policy applies to agent tools that consume these instructions, not only Pi.
No rollout is included; installed profiles require the normal sync process.

## Testing

- Exact text comparison with line breaks normalized: passed.
- `./scripts/check-structure.sh`: passed.
- `git diff --check`: passed.
- Direct evaluation of `checks.aarch64-darwin.sync-agents-settings-merge.drvPath` with evaluation caching disabled: passed.
- `nix flake check --no-build --option eval-cache false`: passed.
- No sync or deployment performed.

## Summary

Added the supplied paragraph verbatim under Communication in `agents/AGENTS.md`, with one sentence per line.
Existing rules and unrelated changes remain intact.
No new extension or generated-file edits were required.
