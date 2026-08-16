# feat-disable-google-drive-teamtailor

> Disable Google Drive and Teamtailor agent tools and skills without affecting historical documentation or unrelated services.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Google Drive is currently exposed through work MCPorter configuration, a generated CLI wrapper, a dedicated skill, and a flake package export for its authentication bridge.
Teamtailor has no active MCP server, but its status-only skill remains exposed to agents.
Neither integration should remain available or discoverable as an agent tool or skill.

## Plan

### Scope

This change affects work MCP configuration, MCP and skill imports, the work profile skill allowlist, generated-wrapper refresh configuration, the Google Drive generated wrapper and package export, and the dedicated Google Drive and Teamtailor skill directories.
The dormant Google Drive authentication bridge source and historical completed plans remain in the repository for provenance and possible future re-enablement.

### Approach

1. Remove Google Drive from active MCP settings, the default MCP catalog, the exported package set, and generated-wrapper refresh configuration.
2. Remove the generated Google Drive CLI and both dedicated skill directories.
3. Remove Google Drive and Teamtailor from preset imports and the work profile skill allowlist.
4. Correct mutable settings synchronization so removed source-managed nested keys replace stale installed keys, and clear derived MCP tool caches after profile sync.
5. Synchronize agent profiles and verify that neither tool nor skill is installed, configured, cached, or exported.

### Risks

Removing the generated wrapper while leaving stale profile output would preserve accidental access until synchronization completes, so installed profile state must be checked after `sync-agents`.
Mutable JSON settings must preserve target-only top-level user keys while replacing source-managed top-level objects such as `mcpServers` so removals take effect.
Derived MCP tool caches are cleared during synchronization because stale schemas can otherwise keep removed integrations discoverable.
The Google Drive bridge source remains dormant and must not be interpreted as an enabled package or MCP server.
Historical documentation continues to mention both integrations as past state.

## Testing

Commands run successfully:

```sh
nixfmt agents/base-settings.nix agents/presets/default.nix agents/presets/profiles.nix flake/apps.nix flake/packages.nix hosts/darwin/work/home.nix
./scripts/check-structure.sh
git diff --check
nix eval --json .#packages.aarch64-darwin --apply builtins.attrNames
nix build .#checks.aarch64-darwin.sync-agents-settings-merge --no-link
nix run .#sync-agents
nix flake check --no-build --option eval-cache false
```

A focused JSON merge test confirmed that target-only top-level user settings remain while a source-managed `mcpServers` object replaces its prior value and removes stale servers.
Post-sync checks confirmed that Google Drive and Teamtailor are absent from MCPorter settings, work and work-factory skill directories, runtime MCP caches, generated wrappers, preset imports, profile allowlists, and flake package exports.
The full flake check passed in a clean worktree containing the cumulative MCP skill changes but excluding unrelated user modifications.
An independent review verified the regression check and concluded that the existing implementation comment documents the merge contract sufficiently, so no broader documentation change is needed.

## Summary

### What changed

- Removed Google Drive from active MCP settings, MCP definitions, wrapper regeneration, generated wrappers, and flake package exports.
- Removed the Google Drive and Teamtailor skills from source and synchronized profiles.
- Corrected mutable JSON settings synchronization to perform its documented shallow top-level merge, allowing removed managed servers to disappear.
- Cleared derived work MCP caches during profile synchronization so stale tool schemas do not preserve disabled integrations.
- Retained the dormant Google Drive authentication bridge source and historical completed plans.

### What was tested

- Formatting, structure, whitespace, source references, flake package exports, the automated shallow-merge regression check, profile synchronization, installed settings and caches, skill removal, and isolated full flake evaluation.

### Follow-up

- None.
