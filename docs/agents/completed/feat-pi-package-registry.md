# feat-pi-package-registry

> Manage selected Pi catalog packages through a local Nix registry.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Several desired Pi capabilities are published in the Pi package catalog and are
installed with `pi install npm:<package>`. Instead of vendoring package sources
or adding ad hoc wrapper logic, this repo should declare the selected packages
and versions in one local registry and feed them into generated Pi
`settings.json`.

## Plan

### Scope

- `agents/external/pi-packages/`
- `modules/home/programs/ai-agents.nix`
- `agents/targets/pi/extensions/subagent/`

### Approach

1. Add a local Pi package registry that records npm package names, versions,
   package types, aliases, and catalog source URLs.
2. Generate `npm:<name>@<version>` package refs from enabled registry entries.
3. Add those package refs to Pi personal and work base settings.
4. Keep `pi-mcp-adapter` as a work-only package.
5. Remove the local `subagent` extension so the external `pi-subagents` package
   owns that capability.

### Risks

- Pi installs npm packages at runtime, so first launch after sync may need
  network access.
- Package behavior can change when registry versions are updated.
- `pi-kanban` benefits from `pi-subagents` and `@juicesharp/rpiv-todo`; both are
  included here.

## Testing

Commands run to validate:

```sh
nixfmt agents/external/pi-packages/default.nix agents/external/pi-packages/registry.nix modules/home/programs/ai-agents.nix
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.fromJSON flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/pi/bases/personal/settings/settings.json".text'
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.fromJSON flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/pi/bases/work/settings/settings.json".text'
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
find /Users/kisw/.config/nix-agents/pi/bases -path '*/extensions/todo' -o -path '*/extensions/subagent' -o -path '*/prompts/implement.md' -o -path '*/prompts/implement-and-review.md' -o -path '*/prompts/scout-and-plan.md'
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Added `agents/external/pi-packages/` as the local Pi package registry.
- Enabled these Pi catalog packages with explicit npm versions:
  - `context-mode@1.0.162`
  - `pi-cost@0.1.1`
  - `pi-dynamic-workflows@1.0.1`
  - `pi-kanban@1.0.0`
  - `pi-lens@3.8.50`
  - `pi-simplify@0.2.2`
  - `pi-subagents@0.28.0`
  - `pi-web-access@0.10.7`
  - `@juicesharp/rpiv-btw@1.19.1`
  - `@juicesharp/rpiv-todo@1.19.1`
- Added those package refs to Pi personal and work settings.
- Kept `pi-mcp-adapter@2.8.0` as a work-only package.
- Removed the local `subagent` extension so `pi-subagents` owns that capability.

### What was tested

- Nix formatting on touched Nix files.
- Evaluated personal and work Pi settings JSON and confirmed package refs.
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- Verified generated Pi profiles no longer contain local `todo`, `subagent`, or
  the removed prompt flow files.
- `apps/aarch64-darwin/build lunar`

### Follow-up

- Run Darwin switch to activate the Home Manager-managed base settings files.
