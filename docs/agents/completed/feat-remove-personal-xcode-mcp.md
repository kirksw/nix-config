# Remove personal Xcode MCP

> Stop configuring Xcode MCP for personal Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The personal Pi bases currently expose `xcrun mcpbridge` through MCPorter and advertise an Xcode skill. Remove that profile integration without disturbing unrelated staged changes to the shared runner and generated wrapper.

## Plan

### Scope

Update `agents/base-settings.nix`, `agents/pi-profiles.nix`, the wrapper-refresh app, and profile inventory references. Leave shared MCP infrastructure, Xcode skill source, and staged generated assets untouched.

### Approach

1. Set the personal MCPorter configuration to an empty server set and remove Xcode from personal skills.
2. Remove the Xcode wrapper-refresh option, update profile inventory references, and validate generated configuration and Nix evaluation.

### Risks

The existing generated Xcode wrapper remains in the repository but is no longer configured or advertised in personal profiles. Active sessions retain their current configuration until agents are synced and restarted.

## Testing

- `./scripts/check-structure.sh` passed.
- `nix flake check --no-build` passed.
- `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link` passed.
- `nix run .#sync-agents` passed.
- Inspected synced `personal` and `personal-default` MCPorter configurations: both have empty server sets; neither personal profile includes the Xcode skill.
- `git diff --check` passed.

## Summary

### What changed

- Removed Xcode MCP configuration and skill assignment from the personal profiles.
- Restricted the MCP wrapper-refresh app to AFFiNE and updated the profile inventories.

### What was tested

- Structure, Nix evaluation, profile build, runtime sync, and synced profile contents.

### Follow-up

- Restart active agent sessions to load the updated profiles.
