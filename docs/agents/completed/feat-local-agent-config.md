# feat-local-agent-config

> Move agent configuration into this repo while keeping nix-agents as a reusable generator input.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Agent definitions, presets, profile policy, Pi extensions, and some local packages currently live in the `nix-agents` input. That makes `nix-agents` hard to open source as a reusable generator/template project because it also contains personal configuration.

## Plan

### Scope

This change affects local agent definitions, generated wrapper inputs, local package outputs, and docs describing the nix-agents repository boundary.

### Approach

1. Add a top-level `agents/` tree containing local definitions, presets, and Pi target assets copied from the current `nix-agents` source.
2. Move non-generator packages used by the local setup into this repo.
3. Rewire `modules/home/programs/ai-agents.nix` to use `inputs.nix-agents.lib` with local module lists and local assets.
4. Update docs and backlog to make upstream `nix-agents` cleanup the next staged PR.

### Risks

- Relative paths in copied definitions must be adjusted so MCP packages and skill source directories resolve inside this repo.
- Wrapper profile metadata must continue to match the existing base/profile layout.
- Upstream cleanup is intentionally deferred until this repo is self-contained.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix build .#multica
nix build .#agent-observe
```

## Summary

### What changed

- Added local `agents/` definitions, presets, profile policy, Pi target assets, and workflow guidance.
- Rewired AI tool wrappers to use local agent modules/assets with `inputs.nix-agents.lib`.
- Moved `multica`, `multica-selfhost`, and `agent-observe` package definitions into this repo.
- Updated `sync-work-skills` to target `work-default` profile directories.
- Documented the engine/config split and tracked upstream cleanup in the backlog.
- Kept sandbox policy out of the local preset until the published `nix-agents` engine exposes the `sandboxes` option.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix build .#multica`
- `nix build .#agent-observe`
- `nix run .#sync-work-skills`

### Follow-up

- P1 M Slim upstream `nix-agents` to engine/templates only after local config migration is stable.
- P2 S Re-enable profile sandbox policy after upstream `nix-agents` publishes the `sandboxes` module API.
