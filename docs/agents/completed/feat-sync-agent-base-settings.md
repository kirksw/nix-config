# feat-sync-agent-base-settings

> Move generated agent base settings out of Home Manager and into `sync-agents`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Home Manager owned several `~/.config/nix-agents/.../settings/*` files directly. That meant a Darwin switch could move existing mutable files such as Pi work `auth.json` aside as backups, and `sync-agents` was not sufficient to deploy every generated agent config change.

## Plan

### Scope

- Shared generated base settings for Codex and Pi.
- Pi work mutable auth seed.
- Codex approval rule seeds.
- `sync-agents` deployment behavior.
- Home Manager AI agent module.

### Approach

1. Centralize generated base settings in `agents/base-settings.nix`.
2. Have `sync-agents` bootstrap those settings into base settings directories as writable files.
3. Preserve/seed base settings and Pi work `auth.json` without replacing existing mutable files.
4. Move Codex approval rule seeding from Home Manager activation into `sync-agents`.
5. Keep Home Manager responsible for tool wrappers, packages, and decrypted secrets only.

### Risks

- Existing Home Manager generations may still contain old managed links until the next switch.
- Base settings and mutable files must not be overwritten by generated sync.
- Profile generation must still merge Codex base settings and generated MCP config correctly.

## Testing

Commands run to validate:

```sh
nixfmt agents/base-settings.nix flake/apps.nix modules/home/programs/ai-agents.nix
./scripts/check-structure.sh
nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); cfg = flake.darwinConfigurations.lunar.config.home-manager.users.kisw; in { hasXdg = cfg ? xdg && cfg.xdg ? configFile; agentXdgPaths = builtins.filter (name: builtins.match "nix-agents/.*" name != null) (builtins.attrNames cfg.xdg.configFile); }'
nix eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); in flake.apps.aarch64-darwin.sync-agents.program'
nix run .#sync-agents
ls -l ~/.config/nix-agents/pi/bases/work/settings ~/.config/nix-agents/codex/bases/work/settings ~/.config/nix-agents/codex/bases/work/profiles/work-default/config.toml
rg -n "lunar-skills|backend-practices|backend-practises" ~/.config/nix-agents/pi/bases/work/settings/mcp.json ~/.config/nix-agents/codex/bases/work/profiles/work-default/config.toml ~/.config/nix-agents/codex/bases/work/settings/config.toml
nix build .#lunar-skills-mcp
nix flake check --no-build
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Added `agents/base-settings.nix` as the repo source for generated Codex and Pi base settings.
- Updated `sync-agents` to bootstrap generated base settings before profile assets.
- Preserved generated base settings and mutable Pi work `auth.json`, restoring existing backups or seeding defaults only when missing.
- Moved Codex approval rule seeding from Home Manager activation into `sync-agents`.
- Removed agent settings and activation hooks from the Home Manager AI agent module.

### What was tested

- Nix formatting on touched Nix files.
- Home Manager evaluation has no `nix-agents/...` `xdg.configFile` entries.
- `sync-agents` bootstraps live base settings and updates generated profile configs.
- Existing base settings remain regular files and are not overwritten by sync.
- Pi work `auth.json` remains a regular `0600` file and is not overwritten by sync.
- Generated Pi and Codex work configs include `lunar-skills`.
- `./scripts/check-structure.sh`
- `nix build .#lunar-skills-mcp`
- `nix flake check --no-build`
- `apps/aarch64-darwin/build lunar`

### Follow-up

- Run Darwin switch to activate wrappers built with the latest sync behavior.
