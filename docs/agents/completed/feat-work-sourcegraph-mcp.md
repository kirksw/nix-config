# feat-work-sourcegraph-mcp

> Manage Linear and Sourcegraph work MCPs through nix-agents profiles instead of hand-written Codex settings.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Codex work config included Linear in both the hand-written base settings and the generated nix-agents MCP config, producing duplicate `mcp_servers.linear` entries. Sourcegraph was also hand-written in Codex-only settings, but it should be available through the general work agent MCP profile alongside Linear.

## Plan

### Scope

- `agents/defs/mcps/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `modules/home/programs/ai-agents.nix`
- Generated Codex sync validation

### Approach

1. Add a Sourcegraph remote MCP definition to the local nix-agents catalog.
2. Import Sourcegraph from the default preset and add it to the work profile MCP list.
3. Remove Linear and Sourcegraph MCP tables from the hand-written Codex work settings so Codex receives them from generated profile MCP config.
4. Add Sourcegraph to Pi work MCP settings, which are currently managed separately from the profile-generated MCP list.
5. Validate formatting and generated Codex work config.

### Risks

- Codex config sync concatenates TOML fragments; stale local generated files can keep duplicates until `sync-agents` or a wrapper refresh runs.
- The Codex base settings file is Home Manager-managed, so updating the live symlink requires a Darwin/Home Manager switch; `sync-agents` alone only resyncs profile assets.
- Pi uses a separate work MCP JSON file, so it must be updated explicitly until Pi consumes profile MCP generation.

## Testing

Commands run to validate:

```sh
nixfmt agents/defs/mcps/sourcegraph.nix agents/presets/default.nix agents/presets/profiles.nix modules/home/programs/ai-agents.nix
./scripts/check-structure.sh
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in builtins.readFile (system + "/mcp.nix.toml")'
nix run .#sync-agents
nix flake check --no-build
apps/aarch64-darwin/build lunar
```

Notes:

- `nix run .#sync-agents` succeeded after staging the new Sourcegraph MCP file for flake visibility.
- Live Codex work config can still show duplicate Linear/Sourcegraph entries until a Darwin switch updates the Home Manager-managed `bases/work/settings/config.toml` symlink. The build output confirms the next generation omits the hand-written Codex MCP tables.

## Summary

### What changed

- Added `agents/defs/mcps/sourcegraph.nix` as a remote MCP definition.
- Imported Sourcegraph in the default agent preset.
- Added Sourcegraph to the work profile `mcpServers` list so work agents receive both Linear and Sourcegraph from nix-agents profile config.
- Removed hand-written Linear and Sourcegraph MCP tables from Codex work base settings.
- Added Sourcegraph to Pi work MCP settings.

### What was tested

- Nix formatting on touched Nix files.
- Repository structure checks.
- Codex work profile MCP generation includes one Linear entry and one Sourcegraph entry in `mcp.nix.toml`.
- `sync-agents` completes.
- `nix flake check --no-build` passes.
- `apps/aarch64-darwin/build lunar` passes and confirms the next Home Manager settings generation has no hand-written Codex MCP tables.

### Follow-up

- Added a backlog item to run Darwin switch and `sync-agents` after this mapping lands so the live Codex base settings symlink picks up the deduped source of truth.
