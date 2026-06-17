# feat-what-if-skill

> Add a `what-if` skill for structured thought experiments, alternative constraint exploration, and adversarial review.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

You want a reusable skill for planning sessions where the point is not immediate implementation, but exploring how a system could look if key constraints changed. The skill should help frame the current state, propose alternative worlds, stress-test them adversarially, and capture the findings even when the answer is ultimately “keep the current tradeoffs”.

## Plan

### Scope

- `agents/defs/skills/what-if/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `docs/agents/feat-what-if-skill.md`

### Approach

1. Add a new directory-backed `what-if` skill with a lean `SKILL.md` and one focused reference for review lenses/output shape.
2. Make the skill guide the model to establish the baseline, isolate the changed constraints, sketch a few plausible alternative worlds, and compare consequences.
3. Include adversarial review guidance so the skill actively looks for failure modes, migration costs, and reasons not to adopt the new world.
4. Register the skill in the default preset and explicitly allow it in `work-default`.
5. Validate with structure and Nix checks, then complete and move the feature note to `docs/agents/completed/`.

### Risks

- The skill could drift into vague brainstorming unless the workflow forces explicit assumptions, consequences, and recommendation criteria.
- There is some overlap with `grill-me` and `parallel-reviews`, so the new skill should stay focused on counterfactual planning rather than generic interviews or generic multi-angle review.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Added a new directory-backed `what-if` skill with a focused workflow for baseline framing, alternative-world generation, adversarial review, and decision capture.
- Added `agents/defs/skills/what-if/references/review-lenses.md` to keep the core skill lean while providing a reusable lens checklist and output template.
- Registered the skill in `agents/presets/default.nix` and enabled it explicitly for `work-default` in `agents/presets/profiles.nix`.

### What was tested

- `./scripts/check-structure.sh`
- `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in builtins.attrNames (builtins.readDir (system + "/skills"))'`
- `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "personal-default"; }; in builtins.attrNames (builtins.readDir (system + "/skills"))'`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- `lens_diagnostics mode=all`

### Follow-up

- None.
