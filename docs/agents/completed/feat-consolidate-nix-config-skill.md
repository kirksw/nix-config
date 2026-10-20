# Consolidate Nix configuration skills

> Replace four overlapping skills with a progressive-disclosure `nix-config` skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`add-module`, `nix-agents`, `secrets-management`, and `system-context` overlap in configuration guidance.
The inline secrets skill describes provider backends and profile fields that are not used by this repository's current environment-variable-only Pi wrapper.

## Plan

### Scope

Consolidate the four skills into `agents/defs/skills/nix-config/` with task recipes and supporting references.
Select the new skill in each profile that previously selected any of the four, remove retired definitions, and update documentation and profile checks.
Leave unrelated staged changes alone.

### Approach

1. Move and reconcile reusable references; add task-oriented recipes and a small routing `SKILL.md`.
2. Replace old skill definitions and profile selection with `nix-config`; update links and inventory checks.
3. Build, inspect generated skill content, sync, and run flake checks.

### Risks

Skills are renamed in generated profiles on sync, but running Pi sessions will need a restart.
Retiring the old skill names may affect references outside this repository.

## Testing

- `./scripts/check-structure.sh`, `nixfmt --check` on changed Nix files, and `git diff --check` passed.
- Verified every relative recipe/reference link resolves.
- `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link` and `nix flake check --no-build` passed.
- `nix run .#sync-agents` passed; all six profiles have `nix-config` and none have the retired skills.
- Independent read-only review found no missing workflow coverage or broken links in the consolidated skill.
- The standalone `scripts/check-pi-experimental-profiles.py` fails on a pre-existing fallback `subagents` assertion. `mkPiMinimalSettings` omits the key correctly, but `sync-agents` preserves target-only JSON keys, leaving the old `subagents` key in live settings. The fresh-root flake check does not exercise upgrades. This is unrelated to skill selection.

## Summary

### What changed

- Replaced four overlapping skills with a short `nix-config` router, six task recipes, and relocated references.
- Reconciled credential advice with the actual environment-variable-only Pi wrapper and base-level provider selection.
- Updated all six profile selections, the inventory check, and active documentation links.

### What was tested

- Structure, format, flake evaluation, profile build, link resolution, and synced profile skill contents.

### Follow-up

- Remove the legacy fallback `subagents` key during sync and add an upgrade-path regression check; keep the assertion, which detects real state drift.
