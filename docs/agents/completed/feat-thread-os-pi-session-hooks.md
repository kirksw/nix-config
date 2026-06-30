# feat-thread-os-pi-session-hooks

> Wire existing Thread OS session hooks into generated Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Thread OS needs Pi sessions to write session start/end records so cmux-spawned worker agents become durable thread artifacts instead of scrollback.

## Plan

### Scope

- `flake/apps.nix`
- `agents/defs/hooks/pi-thread-os-session-start.sh`
- `agents/defs/hooks/pi-thread-os-session-end.sh`

### Approach

1. Keep generated Pi profile metadata hook-free to avoid the current nix-agents `builtins.toFile`/derivation hook-manifest limitation.
2. Have `sync-agents` copy Thread OS hook scripts into Pi profile dirs and write the Pi `hook-manifest` directly.
3. Reuse the existing Python Thread OS context/sync hooks.

### Risks

Low. This enables existing non-fatal hooks. The hook manifest is direct-written for Pi profiles until nix-agents can generate hook manifests with derivation-backed scripts during sync.

## Testing

Commands run to validate:

```sh
nix run .#sync-agents -- --dry-run
bash -n agents/defs/hooks/pi-thread-os-session-start.sh agents/defs/hooks/pi-thread-os-session-end.sh
nix-instantiate --parse flake/apps.nix
```

## Summary

### What changed

- Added small Pi Thread OS session start/end shell wrappers.
- Updated `sync-agents` to install those wrappers plus the existing Python Thread OS hooks into personal/work Pi profiles.
- Updated Pi hook manifests to point at those wrappers during sync.

### What was tested

- `sync-agents --dry-run` builds and shows hook-manifest writes for personal/work Pi profiles.
- Hook shell scripts pass `bash -n`.
- `flake/apps.nix` parses.

### Follow-up

- None for this v0. Replace the direct manifest write when nix-agents supports derivation-backed hook manifests in sync metadata.
