# feat-grill-with-docs-skills

> Add Matt Pocock's `grill-with-docs` workflow and its required `grilling` and `domain-modeling` skills to agent profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`grill-with-docs` explicitly composes `/grilling` and `/domain-modeling`. The three upstream skills should remain linked to the pinned `mattpocock/skills` source rather than copying their instructions into this repository.

## Scope

- Add a lockable, non-flake `mattpocock/skills` input.
- Add local skill definitions for `grill-with-docs`, `grilling`, and `domain-modeling`.
- Register all three in the default preset and explicitly allow them in `work-default`.
- Document the profile behavior and validation.

## What changed

- Added the pinned `mattpocock-skills` flake input with `flake = false`.
- Added directory-backed definitions whose `src` paths point to the upstream engineering/productivity skill directories.
- Enabled `grill-with-docs`, `grilling`, and `domain-modeling` in the default preset and `work-default` allowlist. `personal-default` remains empty=all.
- Updated the system-context base/profile reference.

## Validation

- `./scripts/check-structure.sh` passed.
- Work-profile Codex evaluation produced `domain-modeling`, `grill-with-docs`, and `grilling` in the generated skill list.
- `nix flake check --no-build` was run; the repository's check reached unrelated existing generated-source/OpenClaw path failures, while the skill-specific evaluation passed.

## Follow-up

- None.
