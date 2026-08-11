# feat-fli-pi-skill

> Add the Fli flight-search CLI and a minimal personal Pi skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Personal Pi needs a Nix-managed `fli` CLI for Google Flights searches.
The upstream project distributes it as the Python package `flights`.

## Plan

### Scope

- Add a pinned Nix package for Fli under `packages/fli/`.
- Install it when Pi is enabled.
- Add a thin local skill and include it in the default agent preset.

### Approach

1. Package the upstream `punitarani/fli` source with its required Python dependencies.
2. Expose the package through the existing automatic package discovery.
3. Add `fli` to Pi's runtime packages and provide short CLI guidance.
4. Format, evaluate, build the package, and sync agent assets.

### Risks

- Flight data comes from an unofficial Google Flights API and live requests can be rate-limited or fail upstream.
- Fli's JSON output is documented by upstream as experimental.

## Testing

Commands run to validate:

```sh
nixfmt agents/presets/default.nix agents/defs/skills/fli/default.nix modules/home/programs/ai-agents.nix packages/fli/default.nix
nix build .#fli --no-link
$(nix build .#fli --no-link --print-out-paths)/bin/fli --help
./scripts/check-structure.sh
nix run .#sync-agents
```

All commands above passed.
The personal Pi profile now contains the Fli skill, while the work profile does not.
The factory-profile package assertion was also updated for the existing `pi-mlflow-tracer` package, and the full `nix flake check --no-build --option eval-cache false` passed.

## Summary

### What changed

- Packaged the upstream Fli CLI as `fli`.
- Installed it with Pi and added a thin personal Pi skill.
- Updated the factory-profile assertion for the existing Pi MLflow tracer package.

### What was tested

- Built `.#fli` and ran `fli --help`.
- Confirmed the skill is present in the personal Pi profile and absent from the work profile.
- Ran structure checks and the full flake evaluation.

### Follow-up

- None.
