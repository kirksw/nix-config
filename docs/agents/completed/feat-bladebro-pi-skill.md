# feat-bladebro-pi-skill

> Add Bladebro's native Pi browser extension and a thin personal skill.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Personal Pi needs Bladebro's native extension for its browser-control tools.
The upstream npm package bundles the platform-specific `bladebro` CLI and registers its MCP tools directly with Pi.

## Plan

### Scope

- Add the pinned Bladebro npm extension to personal Pi settings.
- Add a thin local skill and import it through the default agent preset.

### Approach

1. Add `npm:bladebro@3.1.4` only to the personal Pi package list.
2. Provide short guidance for the extension's browser tools and explicit confirmation boundaries.
3. Sync agent assets and verify the generated personal Pi configuration.

### Risks

- Bladebro controls a local Chrome or Chromium instance and can cause external side effects.
- The extension requires a supported platform and a locally installed Chrome or Chromium browser.

## Testing

Commands run to validate:

```sh
nixfmt agents/base-settings.nix agents/defs/skills/bladebro/default.nix agents/presets/default.nix
nix run .#sync-agents
./scripts/check-structure.sh
nix flake check --no-build --option eval-cache false
```

All commands above passed.
The generated personal Pi settings include `npm:bladebro@3.1.4`.
The Bladebro skill is present in the personal profile and absent from the work profile.

## Summary

### What changed

- Added Bladebro's native Pi extension to personal Pi settings.
- Added a thin skill with browser-tool use and confirmation guidance.

### What was tested

- Synced generated agent configuration.
- Confirmed personal-only extension and skill placement.
- Ran structure checks and the full flake evaluation.

### Follow-up

- Restart Pi sessions to load Bladebro's registered browser tools.
