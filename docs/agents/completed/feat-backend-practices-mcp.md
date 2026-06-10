# feat-backend-practices-mcp

> Expose backend-engineering-practices skills to work profiles through MCP instead of eagerly syncing them as profile skills.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Work profiles currently copy every skill from the `backend-engineering-practices` flake input into generated profile skill directories. That makes all practice skills available up front, even when most sessions do not need them.

The desired behavior is to keep work profiles lean and expose those practices through a work-only MCP server so agents can discover and load the relevant practice material on demand.

## Plan

### Scope

- Add a local package for a stdio MCP server backed by `inputs.backend-engineering-practices`.
- Add an MCP definition under `agents/defs/mcps/`.
- Wire the MCP into the default agent preset and `work-default` profile.
- Stop `sync-agents` from copying backend practice skills into work profile skill directories.

### Approach

1. Build a small Python MCP server that indexes `skills/*/SKILL.md`, optional references, and the upstream catalog.
2. Expose focused MCP tools for listing/searching practice skills and reading a chosen skill or reference file.
3. Package the server through Nix with the locked flake input path baked in.
4. Register the server as a local MCP and include it only in `work-default`.
5. Keep `sync-work-skills` available for manual compatibility, but remove the automatic eager overlay from `sync-agents`.

### Risks

- MCP clients differ in how aggressively they start configured servers. This change avoids prompt skill loading, but a client may still start the subprocess when it builds its MCP tool inventory.
- The server must avoid exposing arbitrary files outside the upstream `skills` tree.

## Testing

Commands run to validate:

```sh
python3 -m py_compile packages/backend-practices-mcp/server.py
nixfmt packages/backend-practices-mcp/default.nix agents/defs/mcps/backend-practices.nix agents/presets/default.nix agents/presets/profiles.nix flake/packages.nix flake/apps.nix
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"lunar_skills_search","arguments":{"query":"postgres"}}}\n' | python3 packages/backend-practices-mcp/server.py --skills-root /nix/store/aw0sfdspriyvdr0fvvsq749kx9ylpxsf-source/skills
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; localAgents = import ./agents { inherit pkgs; }; system = flake.inputs.nix-agents.lib.aarch64-darwin.mkAgentSystem { inherit pkgs; target = "codex"; inputs = flake.inputs // { self = flake; }; modules = localAgents.defaultModules; profile = "work-default"; }; in { skills = builtins.attrNames (builtins.readDir (system + "/skills")); mcp = builtins.readFile (system + "/mcp.nix.toml"); }'
nix build path:.#backend-practices-mcp
printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"lunar_skills_read","arguments":{"name":"postgres-sqlc"}}}\n' | ./result/bin/backend-practices-mcp
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
```

## Summary

### What changed

- Added `packages/backend-practices-mcp`, a small stdio MCP server that indexes the locked `backend-engineering-practices` `skills/` tree.
- Added MCP tools to list, search, read a skill, and read a skill reference/script on demand.
- Registered `backend-practices` as a local MCP server and enabled it for `work-default`.
- Removed the automatic backend practice skill overlay copy from `sync-agents`, so work profile skills stay limited to the configured local allowlist.

### What was tested

- Python syntax and direct MCP protocol smoke tests passed.
- The Nix package builds through `path:.#backend-practices-mcp`.
- Generated Codex `work-default` config includes the `backend-practices` MCP server, while generated skills remain `grill-me`, `nix-agents`, `parallel-reviews`, `session-heuristics`, and `system-context`.
- `./scripts/check-structure.sh`, `nix flake check --no-build`, and `nix run .#sync-agents -- --dry-run` passed.

### Follow-up

- None.
