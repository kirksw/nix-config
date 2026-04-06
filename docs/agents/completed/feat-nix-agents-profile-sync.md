# feat-nix-agents-profile-sync

> Align local personal/work tool modules with profile-specific nix-agents outputs.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

This repository currently treats `nix-agents` as a generic asset source and then manually copies
the same generated config into personal/work directories. The local Home Manager modules also make
their own assumptions about where Claude, Codex, and Pi agent assets live.

The result is that `nix-agents` profile support is not actually reflected in the runtime layout
used by this repo.

## Plan

### Scope

- `flake/apps.nix`
- `modules/home/programs/claude-code.nix`
- `modules/home/programs/codex.nix`
- `modules/home/programs/pi-coding-agent.nix`
- `docs/agents/feat-nix-agents-profile-sync.md`

### Approach

1. Build explicit `personal` and `work` nix-agents outputs in `flake/apps.nix` instead of copying
   the same config twice.
2. Sync each target's generated assets into profile-specific local directories.
3. Update local Claude, Codex, and Pi wrappers to use the matching profile-specific asset roots at
   runtime.
4. Validate with `nix flake check --no-build` and `nix run .#sync-agents`.

### Risks

- OpenCode still owns its tool-native config locally, so only its agent assets are synced from
  profile-specific nix-agents outputs.
- Pi still needs a live `~/.pi/agent` directory, so the wrapper must project the selected profile's
  synced assets into that fixed location before launching the tool.

## Testing

Commands run to validate:

```sh
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Updated `flake/apps.nix` to build explicit `personal` and `work` nix-agents outputs for
  OpenCode, Claude, Codex, and Pi instead of copying the same generated config into both
  profile directories.
- Updated the sync layout so Claude, Codex, and Pi now sync into profile-specific
  `~/.local/share/nix-agents/.../profiles/<name>` directories.
- Updated the Claude wrapper to select the matching profile-specific nix-agents config root
  and pass the synced `settings.json` and `.mcp.json` at runtime.
- Updated the Codex wrapper to export `CODEX_CONFIG_DIR` from the matching profile-specific
  nix-agents asset directory.
- Updated the Pi wrapper to project the selected profile's synced nix-agents assets into the
  live `~/.pi/agent` directory before launching the tool.

### What was tested

- `nix flake check --no-build`
- `nix run .#sync-agents`

### Follow-up

- None.
