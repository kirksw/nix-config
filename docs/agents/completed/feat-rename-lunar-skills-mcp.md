# feat-rename-lunar-skills-mcp

> Rename the backend practices MCP surface to `lunar-skills`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The MCP server exposes Lunar skill tools named `lunar_skills_*`, but the server
was registered as `backend-practices`. That made work profile MCP lists harder
to recognize and left Pi work settings without the same Lunar skills MCP entry.

## Plan

### Scope

- `agents/defs/mcps/`
- `agents/presets/`
- `packages/`
- `agents/base-settings.nix`
- generated work profile MCP configs

### Approach

1. Rename the MCP definition from `backend-practices` to `lunar-skills`.
2. Rename the package and binary from `backend-practices-mcp` to
   `lunar-skills-mcp`.
3. Update work profile MCP lists to reference `lunar-skills`.
4. Add `lunar-skills` to generated Pi work MCP settings.
5. Update docs and validation references.

### Risks

- Existing running sessions need restart/reload after sync/switch to pick up the
  renamed MCP server.
- Any manual config still referencing `backend-practices` will need updating.

## Testing

Commands run to validate:

```sh
nixfmt agents/defs/mcps/lunar-skills.nix agents/presets/default.nix agents/presets/profiles.nix flake/packages.nix flake/apps.nix modules/home/programs/ai-agents.nix packages/lunar-skills-mcp/default.nix
python3 -m py_compile packages/lunar-skills-mcp/server.py
nix eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in builtins.readFile (system + "/mcp.nix.toml")'
nix run .#sync-agents
rg -n "lunar-skills|backend-practices|backend-practises" ~/.config/nix-agents/pi/bases/work/settings/mcp.json ~/.config/nix-agents/codex/bases/work/profiles/work-default/config.toml
./scripts/check-structure.sh
nix build .#lunar-skills-mcp
nix flake check --no-build
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Renamed the MCP definition from `backend-practices` to `lunar-skills`.
- Renamed the package and binary from `backend-practices-mcp` to
  `lunar-skills-mcp`.
- Updated work profile MCP lists to reference `lunar-skills`.
- Added `lunar-skills` to the generated Pi work MCP JSON.
- Updated docs and nix-agents failure-triage wording.

### What was tested

- Nix formatting on touched Nix files.
- Python bytecode compilation for the renamed MCP server.
- Generated Codex work MCP config includes `[mcp_servers.lunar-skills]`.
- Generated Pi work base MCP JSON includes `lunar-skills`.
- `./scripts/check-structure.sh`
- `nix build .#lunar-skills-mcp`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- `apps/aarch64-darwin/build lunar`

### Follow-up

- Run Darwin switch to activate wrappers built with the latest generated agent config.
