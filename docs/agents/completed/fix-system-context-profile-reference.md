# fix-system-context-profile-reference

> Align the model-facing system-context profile reference with the current lean, full, and work configurations.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The `system-context` skill remains visible in `personal-default`, but its base/profile reference still says that the default profile exposes every agent and skill.
It omits `personal-full`, lists obsolete skills, understates the work profile, and describes the old generated directory shape.
Loading the reference therefore gives the model incorrect source-of-truth guidance.

## Plan

### Scope

- Update `agents/defs/skills/system-context/references/bases-and-profiles.md`.
- Validate the synchronized lean, full, and work skill copies.

### Approach

1. Describe all current bases, including the explicit `personal-full` escape hatch.
2. Replace stale profile descriptions with the authoritative agent and skill allowlists from `agents/presets/profiles.nix`.
3. Clarify that MCP access is provided through generated CLI skills rather than direct MCP tools.
4. Correct profile resolution and generated directory paths.
5. Synchronize profiles and compare generated references with the source.

### Risks

- Explicit allowlists can become stale when presets change; validation should compare generated content with source after synchronization.
- `work-default` remains intentionally broad until a separate work-profile optimization is designed.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
cmp agents/defs/skills/system-context/references/bases-and-profiles.md \
  ~/.config/nix-agents/pi/bases/personal/profiles/personal-default/skills/system-context/references/bases-and-profiles.md
```

## Summary

### What changed

- Documented the lean `personal-default` agent, skill, and package surface.
- Added the explicit `personal-full` base/profile and launch commands.
- Replaced the stale work profile summary with its current nine-agent and 23-skill allowlists.
- Clarified direct MCP exposure, profile resolution, generated paths, and source-of-truth rules.

### What was tested

- Diff and repository structure checks passed.
- Uncached flake evaluation passed after targeted evaluation cleared the recurring transient invalid Nix store-path failure.
- Agent profiles synchronized successfully.
- Lean personal, full personal, and work generated references match the authoritative source byte-for-byte.

### Follow-up

- No follow-up work is required.
