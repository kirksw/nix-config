# feat-work-1password-mcp

> Add the official 1Password local MCP server to work agent profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Work profiles already expose Linear, Sourcegraph, Granola, and local work MCPs. 1Password now ships an official local MCP server from the desktop app for 1Password Environments, launched on macOS at `/Applications/1Password.app/Contents/MacOS/onepassword-mcp` after enabling **Settings > Labs > MCP Server** and **Settings > Developer > Integrate with MCP clients**.

## Plan

### Scope

- `agents/defs/mcps/`
- `agents/presets/default.nix`
- `agents/presets/profiles.nix`
- `agents/base-settings.nix`

### Approach

1. Add a local `1password` MCP definition using the official desktop app binary path.
2. Import it in the default preset and add it to `work-default.mcpServers`.
3. Add the same server to Pi's current work MCP JSON shim.
4. Validate formatting, structure, and generated work MCP output.

### Risks

- The 1Password desktop app feature must be enabled manually before clients can connect.
- The command path is macOS-specific; this matches the current work profile host usage.

## Testing

Commands run to validate:

```sh
nixfmt agents/defs/mcps/1password.nix agents/presets/default.nix agents/presets/profiles.nix agents/base-settings.nix
./scripts/check-structure.sh
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in builtins.readFile (system + "/mcp.nix.toml")'
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; base = import ./agents/base-settings.nix { self = flake; inherit (pkgs) lib; system = "aarch64-darwin"; }; in base.targets.pi.work."mcp.json"'
nix flake check --no-build
nix run .#sync-agents
```

## Summary

### What changed

- Added `agents/defs/mcps/1password.nix` for the official local 1Password desktop MCP binary.
- Imported the MCP definition in the default agent preset.
- Enabled `1password` in the `work-default` profile MCP list.
- Added the same local MCP command to Pi's work `mcp.json` shim with lazy lifecycle.

### What was tested

- Nix formatting and repository structure checks.
- Generated Codex work MCP config contains one `1password` server with the expected command.
- Generated Pi work MCP JSON contains the expected `1password` command and lazy lifecycle.
- `nix flake check --no-build`.
- `nix run .#sync-agents`.
- `code-red` security review reported no blockers.

### Follow-up

- None.
