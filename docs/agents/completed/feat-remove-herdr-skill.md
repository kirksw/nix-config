# feat-remove-herdr-skill

> Remove the redundant Herdr runtime skill and keep the native `herdr` tool as the single model-facing interface.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The `pi-herdr` package registers a structured native tool and also exposes an operating skill.
The skill duplicates the tool interface and its metadata conflicts with the tool policy by requiring explicit user invocation while the native tool guidance permits long-running and parallel work.
The skill is exposed transitively through package metadata, so profile skill allowlists cannot remove it.

## Plan

### Scope

- Update `agents/packages/pi-herdr/package.json` to describe an extension-only package.
- Remove `agents/packages/pi-herdr/skills/herdr/SKILL.md` and its empty parent directories.
- Retain the completed historical feature record without rewriting history.

### Approach

1. Remove the package `pi.skills` entry and `pi-skill` keyword.
2. Update the package description to remove the operating-skill claim.
3. Delete the Herdr skill source.
4. Keep the existing native-tool guidance unchanged: environment gating, current-workspace targeting, focus preservation, and refusal to close Pi's own pane are already implemented; destructive-action approval is covered by the global working agreement; bare CLI and server-stop rules do not apply to the structured tool.
5. Test the package, evaluate the flake, synchronize profiles, and verify that the synchronized package no longer contains a Herdr skill.

### Risks

- Detailed raw-CLI examples will no longer be available as an on-demand skill.
- Rare CLI-only operations will require direct `herdr --help` discovery or repository documentation.
- Existing sessions retain the old skill catalog until restarted.

## Testing

Commands run to validate:

```sh
npm test --prefix agents/packages/pi-herdr
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
```

## Summary

### What changed

- Removed the Herdr skill registration from `agents/packages/pi-herdr/package.json`.
- Deleted `agents/packages/pi-herdr/skills/herdr/SKILL.md` and its empty directories.
- Updated package metadata to describe an extension-only package.
- Kept the structured native tool as the single model-facing Herdr interface.

### What was tested

- Both `pi-herdr` argument tests passed.
- Diff and repository structure checks passed.
- Uncached flake evaluation passed after targeted evaluation cleared a transient invalid Nix store-path failure.
- Agent profiles synchronized successfully.
- The synchronized lean and full package sources contain only `pi.extensions` and no Herdr skill path.

### Follow-up

- No follow-up work is required.
