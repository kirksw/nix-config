# Nix-Agents Flake Operations

## Local Validation Targets

This repo uses `nix-agents` as a library. Wrapped binaries are installed through
`modules/home/programs/ai-agents.nix`, and generated assets are synced by wrappers at runtime.

## Common Commands

```bash
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

Before running a sync app from memory or older docs, verify the actual outputs:

```bash
nix flake show --all-systems 2>/dev/null | rg 'sync'
```

## Check Suite

`nix flake check --no-build` evaluates:

- Home Manager and nix-darwin configurations
- flake apps
- package outputs
- deploy schema checks
- repository pre-commit check

Expected non-fatal warnings in this repo:

- `warning: The following flake outputs are unchecked: deploy.`
- `warning: The check omitted these incompatible systems: ...`
- `warning: Git tree ... has uncommitted changes` when the worktree is dirty

## Workflow After Any Change

After modifying `agents/`, `modules/home/programs/ai-agents.nix`, or local agent packages:

1. `./scripts/check-structure.sh`
2. `nix flake check --no-build`
3. `nix run .#sync-agents`
4. Build any touched package, for example `nix build .#agent-observe`

For Darwin/Home Manager changes, prefer build-oriented validation from the agent:

```bash
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

Use `sudo darwin-rebuild switch --flake .#lunar` only when activation behavior matters. In noninteractive tool sessions, sudo may hang; ask the user to run the switch from their terminal when needed.

## Using `nix-agents` In Your Own Flake

```nix
inputs.nix-agents.url = "github:kirksw/nix-agents";

packages.my-config = nix-agents.lib.${system}.mkAgentSystem {
  inherit pkgs;
  modules = [ ./agents/presets/default.nix ./agents/presets/profiles.nix ];
  target = "opencode";
};
```

## Initialize From Template

```bash
nix flake init -t github:kirksw/nix-agents
```

## Guardrails

- Run `nix flake check --no-build` before committing
- Use `nix run .#sync-agents` to roll out agent-only changes without `darwin-rebuild switch`
- Do not edit the `result` symlink from `nix build`
- Do not edit generated files under `~/.config/nix-agents` as the source of truth
- If Nix reports daemon/socket or fetcher-lock permission errors, rerun with normal Nix access before changing code
