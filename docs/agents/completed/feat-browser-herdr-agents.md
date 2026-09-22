# feat-browser-herdr-agents

> Use `pi-herdr-agents` for Pi browser profiles as well as default profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi default profiles replace `@tintinweb/pi-subagents` with the pinned, locally patched `pi-herdr-agents` package.
Browser profiles currently bypass that settings transformation and continue to load Tintinweb, so projects launched with `pix --profile browser` get a different subagent implementation.

## Plan

### Scope

- `agents/base-settings.nix`
- `scripts/check-pi-experimental-profiles.py`
- `agents/defs/skills/system-context/references/bases-and-profiles.md`

### Approach

1. Rename the default-profile settings helper to describe Herdr settings rather than the former experimental profile.
2. Apply the same transformation to personal and work browser settings while preserving each browser profile's package and MCP differences.
3. Update generated-profile assertions and documentation to require `pi-herdr-agents` in default and browser profiles and retain Tintinweb only in fallback profiles.
4. Run focused profile-generation checks, repository structure checks, formatting checks, and inspect the final diff.

### Risks

- Applying the complete default transformation also removes `rpiv-btw`, `context-mode`, and `pi-observational-memory` and adds `pi-context-flow` and Plannotator to browser profiles; this is required because `pi-herdr-agents` conflicts with the old orchestration package surface.
- Existing Pi browser processes retain extensions loaded at startup and must be restarted after profile synchronization.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nixfmt --check agents/base-settings.nix
python3 -m py_compile scripts/check-pi-experimental-profiles.py
git diff --check
nix flake check --no-build
nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link
nix run .#sync-agents
PI_OFFLINE=1 pi list
```

The focused profile build, profile sync, structure check, format check, Python syntax check, diff check, and live `personal-browser` package inspection passed.
`nix flake check --no-build` remains blocked by an unrelated OpenClaw QMD schema assertion in the existing worktree state.

## Summary

### What changed

- Renamed the shared settings transformation to `mkPiHerdrSettings` and applied it to default and browser profiles.
- Kept Tintinweb only in fallback profiles.
- Updated profile assertions and system-context documentation for the new browser behavior.
- Synchronized generated local profiles; both personal and work browser profiles now reference the patched `pi-herdr-agents` package.

### What was tested

- The focused `pi-experimental-profiles` Nix check built successfully.
- Structure, Nix formatting, Python syntax, and diff whitespace checks passed.
- `pi list` under `personal-browser` reports `pi-herdr-agents` and no Tintinweb package.
- Full flake evaluation reached an unrelated pre-existing OpenClaw QMD schema assertion.

### Follow-up

- None.
