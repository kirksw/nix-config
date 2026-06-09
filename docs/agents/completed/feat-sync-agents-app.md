# feat-sync-agents-app

> Add a non-sudo app to sync generated agent assets into the local profile tree.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Agent/skill/extension changes currently reach the live machine through the Home Manager/nix-darwin wrapper install path, which requires `darwin-rebuild switch` and sudo. That blocks agent-only changes from being rolled out during an agent flow. A user-level `sync-agents` app can copy generated assets from the current flake into `~/.config/nix-agents/...` without switching the system.

## Plan

### Scope

- `flake/apps.nix`
- `flake.nix`
- `agents/defs/skills/nix-agents/references/flake-ops.md`
- This feature plan document

### Approach

1. Add a `sync-agents` flake app that evaluates local `agents/` modules for each target/profile and syncs generated subtrees/files into the matching base/profile directories.
2. Preserve state and user settings by syncing only generated assets (`agents`, `skills`, prompts/extensions, generated markdown/config files) and leaving sessions/auth/state alone.
3. Fold in work skill overlay syncing so `sync-agents` supersedes the narrower `sync-work-skills` app while keeping the old app available.
4. Add `--dry-run` for safe validation from agent sessions.
5. Update skill docs and validate with structure checks and flake check.

### Risks

- Existing installed wrappers still embed a store path from the last Darwin/Home Manager activation. If a stale wrapper launches after a manual sync, it may overwrite generated assets from its embedded generation. This app still removes the sudo requirement for active sessions and explicit sync flows, but wrapper architecture may need a follow-up to prefer a mutable synced source.
- The sync app needs to avoid deleting session/state directories.

## Testing

Commands run to validate:

```sh
nixfmt flake/apps.nix flake.nix agents/defs/skills/nix-agents/default.nix
./scripts/check-structure.sh
nix flake check --no-build
nix flake show --all-systems 2>/tmp/flake-show-err | rg 'sync'
nix run .#sync-agents -- --dry-run
```

Results:

- Formatting completed.
- Structure checks passed.
- `nix flake check --no-build` passed, including `apps.aarch64-darwin.sync-agents.isValidApp`.
- Flake show lists both `sync-agents` and `sync-work-skills`.
- `sync-agents --dry-run` builds generated config and prints intended sync operations without changing files.

## Summary

### What changed

- Added `sync-agents` app to `flake/apps.nix` for non-sudo rollout of generated agent assets across opencode, claude, codex, and pi profiles.
- The app syncs generated assets only, preserves state/session/settings directories, merges Codex config like the wrapper, and applies the backend-engineering-practices work skill overlay.
- Kept existing `sync-work-skills` for narrower compatibility.
- Passed `self` into app construction so local agent modules with `inputs.self` package references evaluate correctly.
- Updated `nix-agents` skill docs to prefer `nix run .#sync-agents` for agent-only rollout.

### What was tested

- `nixfmt flake/apps.nix flake.nix agents/defs/skills/nix-agents/default.nix`
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix flake show --all-systems 2>/tmp/flake-show-err | rg 'sync'`
- `nix run .#sync-agents -- --dry-run`

### Follow-up

- Added `P2 S` backlog item: teach installed nix-agents wrappers to prefer a mutable `sync-agents` generation so stale wrappers do not overwrite manual sync output.
