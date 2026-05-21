# Nix-Agents Flake Operations

## Local Validation Targets

This repo uses `nix-agents` as a library. Wrapped binaries are installed through
`modules/home/programs/ai-agents.nix`, and generated assets are synced by wrappers at runtime.

## Common Commands

```bash
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-work-skills
```

## Check Suite

`nix flake check --no-build` evaluates:

- Home Manager and nix-darwin configurations
- flake apps
- package outputs
- deploy schema checks
- repository pre-commit check

## Workflow After Any Change

After modifying `agents/`, `modules/home/programs/ai-agents.nix`, or local agent packages:

1. `./scripts/check-structure.sh`
2. `nix flake check --no-build`
3. Build any touched package, for example `nix build .#agent-observe`

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
- Do not edit the `result` symlink from `nix build`
- Do not edit generated files under `~/.config/nix-agents` as the source of truth
