# feat-remove-unused-agent-tiers

> Remove the unused organizational tier property from Pi subagent definitions.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Every local Pi subagent declared `tier = "employee"`.
The property has no consumers in this repository and does not determine a subagent model.
Profile-level S–E `tierMapping` remains unchanged.

## Plan

### Scope

- `agents/defs/agents/*.nix`
- `flake.nix`
- This feature plan

### Approach

1. Remove `tier = "employee";` from each local subagent definition.
2. Update the factory-profile check to validate each configured package list.
3. Confirm no such properties remain and evaluate the flake configuration.

### Risks

The factory-profile assertion compared package lists to a stale generic default.
The revised check retains explicit package expectations and normalizes source-store paths for local packages.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nixfmt --check agents/defs/agents/*.nix
nix build .#checks.aarch64-darwin.agentic-factory-profiles --no-link --option eval-cache false
nix flake check --no-build --option eval-cache false
git diff --check
```

All commands passed.
A formatter comparison found only one pre-existing formatting difference in `flake.nix`, outside this change.

## Summary

### What changed

- Removed the unused `tier = "employee";` property from all nine Pi subagent definitions.
- Updated the factory-profile check for the configured home and work package lists.
- Normalized local package source-store paths before comparison so the check is reproducible across source paths.

### What was tested

- Structure, agent-definition formatting, targeted factory-profile check, full no-build flake check, and diff hygiene all passed.

### Follow-up

- None.
