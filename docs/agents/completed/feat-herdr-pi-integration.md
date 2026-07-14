# feat-herdr-pi-integration

> Install Herdr's official Pi lifecycle/session integration declaratively through the Nix-managed Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Herdr restores pane geometry and working directories, but Pi apps are not resumed because the official Herdr Pi integration is not installed. The local `pi-herdr` package provides orchestration only and does not report native Pi session references.

## Plan

### Scope

- `modules/home/programs/ai-agents.nix`
- `modules/home/programs/developer.nix`
- Nix-managed Pi profile extension paths for personal, work, and factory profiles.

### Approach

1. Fetch the official Pi integration asset from the Herdr v0.7.3 release source with a fixed hash.
2. Install that asset into every Nix-managed Pi profile's `extensions` directory via Home Manager.
3. Explicitly enable Herdr's agent resume setting in the declarative config.
4. Validate structure and flake evaluation without changing Herdr's runtime session state.

### Risks

- The pinned integration asset must be updated when the packaged Herdr version changes.
- This restores Pi sessions, not arbitrary non-agent commands; those still require explicit startup commands.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix eval --json '.#darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile' | jq -r 'keys[]' | grep herdr-agent-state.ts
```

## Summary

### What changed

- Added the official Herdr v0.7.3 Pi integration as a pinned Nix fetch.
- Installed it into all four Nix-managed Pi profile extension directories.
- Explicitly enabled `resume_agents_on_restore` in Herdr's declarative config.

### What was tested

- Structure checks passed.
- `nix flake check --no-build` passed.
- Nix evaluation exposed all four expected integration targets.

### Follow-up

- Update the pinned integration URL/hash when the packaged Herdr version changes.
