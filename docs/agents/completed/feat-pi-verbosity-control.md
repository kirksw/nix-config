# feat-pi-verbosity-control

> Add pinned per-model verbosity controls to all generated Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The personal, work, and factory Pi profiles should load `pi-verbosity-control` declaratively so supported OpenAI models can use per-model response verbosity settings.
The upstream npm package was reviewed before installation because Pi extensions execute with full local access.
Version `0.3.0` reads and writes `~/.pi/agent/verbosity.json`, mutates supported OpenAI Responses API requests, registers verbosity shortcuts, and optionally monkeypatches Pi's footer renderer.
The reviewed package source does not declare runtime dependencies or perform network or subprocess operations.

## Plan

### Scope

- `agents/base-settings.nix` — add the pinned package to shared interactive and factory package references.
- `docs/agents/feat-pi-verbosity-control.md` — record the plan, source review, implementation, and validation.

### Approach

1. Add `npm:pi-verbosity-control@0.3.0` to `piPackageRefs` for personal and work profiles.
2. Add the same pinned package to `piFactoryPackageRefs` for home and work factory profiles.
3. Validate formatting, structure, generated settings, and the flake without editing generated profile files directly.
4. Sync the updated agent settings after checks pass.

### Risks

- The extension can modify outbound request bodies for supported OpenAI Responses APIs.
- Cycling verbosity writes user-level state to `~/.pi/agent/verbosity.json`.
- The optional footer indicator uses an upstream runtime monkeypatch, but it is disabled by default.
- Initial installation requires npm registry access.

## Testing

Commands run:

```sh
nixfmt --check agents/base-settings.nix
git diff --check
./scripts/check-structure.sh
nix eval --impure --json --expr '<generated Pi package assertions>'
nix run .#sync-agents
nix flake check --no-build --no-eval-cache
```

The first cached `nix flake check --no-build` attempt reused invalid cached derivation failures.
The required no-eval-cache run passed after `sync-agents` built the current agent source derivation.

## Summary

### What changed

- Added pinned `npm:pi-verbosity-control@0.3.0` references to shared interactive and factory Pi package lists.
- Synced the generated personal, work, home-factory, and work-factory Pi settings.
- Reviewed the published npm package source and documented its request, filesystem, shortcut, and footer behavior.

### What was tested

- Nix formatting and diff whitespace checks passed.
- Repository structure checks passed.
- Generated settings assertions found exactly one pinned package reference in each of the four Pi base settings.
- Agent configuration sync passed.
- The full flake check passed with `--no-eval-cache`.

### Follow-up

- None.
