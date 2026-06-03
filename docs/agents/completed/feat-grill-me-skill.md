# feat-grill-me-skill

> Add Matt Pocock's `grill-me` planning interview skill to personal and work agent profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Personal and work profiles should include lightweight skills for stress-testing plans and designs. `grill-me` provides a one-question-at-a-time interview workflow, while `parallel-reviews` gives the work profile a broader multi-perspective review workflow.

## Plan

### Scope

- `agents/defs/skills/grill-me/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `agents/defs/skills/system-context/references/bases-and-profiles.md`

### Approach

1. Import the upstream `grill-me` skill instructions as a local directory-backed skill.
2. Register the skill in the default preset.
3. Add the skill to the explicit `personal-default` and `work-default` skill allowlists.
4. Update the base/profile reference documentation.

### Risks

The skill overlaps slightly with `parallel-reviews`, but its interaction pattern is distinct: one question at a time rather than a multi-perspective review.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "personal-default"; }; in builtins.attrNames (builtins.readDir (system + "/skills"))'
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in builtins.attrNames (builtins.readDir (system + "/skills"))'
nix flake check --no-build
```

## Summary

### What changed

- Added the `grill-me` skill from `mattpocock/skills`.
- Registered it in the default agent preset.
- Enabled it for `personal-default` and `work-default`.
- Enabled `parallel-reviews` for `work-default`.
- Updated profile documentation.

### What was tested

- Structure checks.
- Generated personal Codex profile skill list includes `grill-me`.
- Generated work Codex profile skill list includes `grill-me`, `nix-agents`, `parallel-reviews`, and `system-context`.
- Flake checks without builds.

### Follow-up

- None.
