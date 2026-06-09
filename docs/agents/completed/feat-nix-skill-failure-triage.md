# feat-nix-skill-failure-triage

> Add reusable Nix failure triage guidance to the nix-agents skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Recent session-mined heuristics found recurring Nix failure modes in this repo: Darwin dependency chains from `gitFull`, Home Manager out-of-store symlink issues, sandboxed Nix daemon access failures, stale sync app names, and expected flake check warnings. The `nix-agents` skill should point agents at these recovery paths before they start broad debugging.

## Plan

### Scope

- `agents/defs/skills/nix-agents/SKILL.md`
- `agents/defs/skills/nix-agents/references/flake-ops.md`
- `agents/defs/skills/nix-agents/references/failure-triage.md`
- `agents/defs/skills/nix-agents/default.nix`
- This feature plan document.

### Approach

1. Add a compact failure-triage reference with known signatures, first actions, and validation flow.
2. Link the new reference from `SKILL.md` and add working rules for daemon/sandbox errors and actual flake app discovery.
3. Update flake operations guidance with expected warnings, Darwin validation notes, and sync-app verification.
4. Run structural and no-build flake validation.

### Risks

- Guidance could become stale if flake app names change; mitigate by recommending `nix flake show` discovery.
- Some errors are contextual; keep guidance as triage, not absolute fixes.

## Testing

Commands run to validate:

```sh
nixfmt agents/defs/skills/nix-agents/default.nix
./scripts/check-structure.sh
nix flake check --no-build
```

Results:

- `nixfmt agents/defs/skills/nix-agents/default.nix` completed.
- `./scripts/check-structure.sh` passed.
- `nix flake check --no-build` passed. Expected warnings remained for dirty tree, unchecked `deploy`, and incompatible systems omitted.

## Summary

### What changed

- Added `references/failure-triage.md` with a triage flow, known Nix error signatures, Darwin/Home Manager validation guidance, and sync-app discovery instructions.
- Linked the new reference from `SKILL.md` and added working rules for failure triage, sandbox/daemon errors, and stale sync commands.
- Expanded `flake-ops.md` with sync output discovery, expected non-fatal warnings, Darwin build validation, and Nix access guardrails.
- Bumped the directory-backed skill version to `1.1.0`.

### What was tested

- `nixfmt agents/defs/skills/nix-agents/default.nix`
- `./scripts/check-structure.sh`
- `nix flake check --no-build`

### Follow-up

- None.
