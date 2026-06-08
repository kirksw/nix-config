# feat-session-heuristics-skill

> Add a skill for mining previous Claude, Codex, and Pi sessions for reusable heuristics.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The user asked for a skill that looks at previous sessions and extracts heuristics
when an agent completed a complex task, recovered from an error, was corrected by
the user, or demonstrated a reusable non-trivial workflow.

## Plan

### Scope

- `agents/defs/skills/session-heuristics/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`

### Approach

1. Create a directory-backed skill with concise trigger guidance.
2. Add references for extraction rules and session source locations.
3. Add a helper script to find recent candidate session files.
4. Import the skill into the default preset and make it available in the work profile.
5. Validate structure and Nix evaluation.

### Risks

Session formats differ across tools and versions. The skill uses candidate discovery
and heuristic filtering rather than assuming a single stable schema.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
agents/defs/skills/session-heuristics/scripts/find-session-candidates.sh 5
nix flake check --no-build
```

## Summary

### What changed

- Added the `session-heuristics` skill.
- Added extraction and session-source references.
- Added a candidate finder script for Claude, Codex, Pi, and nix-agents summary files.
- Imported the skill into default agent modules and work profile skills.

### What was tested

- `./scripts/check-structure.sh` passed.
- `agents/defs/skills/session-heuristics/scripts/find-session-candidates.sh 5` returned recent session-shaped Codex JSONL candidates.
- `nix flake check --no-build` passed.
- `git diff --check` passed.

### Follow-up

- None.
