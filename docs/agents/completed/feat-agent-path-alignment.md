# feat-agent-path-alignment

> Align synced AI agent assets under `~/.config/nix-agents/<tool>/profiles/<profile>/` across this repo and `nix-agents`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

This repository currently syncs AI agent assets to a mixed set of locations. OpenCode uses
tool-native profile directories, while Claude, Codex, and Pi use
`~/.local/share/nix-agents/<tool>/profiles/<profile>`.

That makes the local wrappers, sync output, and the standalone `nix-agents` repository drift from
each other. A single canonical sync root is easier to reason about and aligns better with the
profile-oriented layout already in use.

## Plan

### Scope

- `flake/apps.nix`
- `modules/home/programs/opencode.nix`
- `modules/home/programs/claude-code.nix`
- `modules/home/programs/codex.nix`
- `modules/home/programs/pi-coding-agent.nix`
- `AGENTS.md`
- `/Users/kisw/git/github.com/kirksw/nix-agents/main/lib/core/builders.nix`
- `/Users/kisw/git/github.com/kirksw/nix-agents/main/flake.nix`
- `/Users/kisw/git/github.com/kirksw/nix-agents/main/README.md`

### Approach

1. Change this repo's `sync-agents` app to sync profile-specific assets to
   `~/.config/nix-agents/<tool>/profiles/<profile>/`.
2. Update the local OpenCode, Claude, Codex, and Pi wrappers to consume the same canonical paths.
3. Update `nix-agents/main` wrapper logic, sync app, and docs to use the same path convention.
4. Validate with `nix flake check --no-build` and `nix run .#sync-agents`, then complete and move
   this plan doc.

### Risks

- OpenCode still has tool-native runtime config under `~/.config/opencode/profiles/...`, so only
  the synced agent assets should move to the canonical `nix-agents` directory.
- Pi still requires a live `~/.pi/agent` directory, so the wrapper must keep projecting the
  selected profile there.

## Testing

Commands run to validate:

```sh
nix flake check --no-build
nix run .#sync-agents
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Updated `flake/apps.nix` so `nix run .#sync-agents` now syncs OpenCode, Claude, Codex, and Pi
  assets into `~/.config/nix-agents/<tool>/profiles/<profile>/`.
- Updated the local OpenCode, Claude, Codex, and Pi wrappers to read the same canonical
  `~/.config/nix-agents/.../profiles/...` directories at runtime.
- Updated `AGENTS.md` so the repository guidance describes the canonical synced asset layout instead
  of the old OpenCode-only paths.
- Updated `/Users/kisw/git/github.com/kirksw/nix-agents/main/lib/core/builders.nix` so wrapped
  tools project generated assets into the same `~/.config/nix-agents/<tool>/profiles/<profile>/`
  layout.
- Updated `/Users/kisw/git/github.com/kirksw/nix-agents/main/flake.nix` so its `sync` app writes
  OpenCode, Claude, Codex, and Pi assets into matching `default` profile directories under the same
  canonical root.
- Updated `/Users/kisw/git/github.com/kirksw/nix-agents/main/README.md` to document the new path
  convention.

### What was tested

- `nix flake check --no-build` in `/Users/kisw/git/github.com/kirksw/nix-config`
- `nix run .#sync-agents` in `/Users/kisw/git/github.com/kirksw/nix-config`
- Spot-checked synced outputs under:
  `~/.config/nix-agents/opencode/profiles/{personal,work}`,
  `~/.config/nix-agents/claude/profiles/{work}`,
  `~/.config/nix-agents/codex/profiles/{work}`,
  `~/.config/nix-agents/pi/profiles/{personal}`
- `nix flake check --no-build` in `/Users/kisw/git/github.com/kirksw/nix-agents/main`
- `nix run .#sync` in `/Users/kisw/git/github.com/kirksw/nix-agents/main`
- Spot-checked synced outputs under:
  `~/.config/nix-agents/{opencode,claude,codex,pi}/profiles/default`

### Follow-up

- None.
