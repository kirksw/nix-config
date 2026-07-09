# Nix Config

## Overview

Nix flake repository for macOS (`nix-darwin`) and Linux (`NixOS`) hosts.

## Structure

- `hosts/`: concrete host modules (actual machine configuration).
- `flake/hosts/`: host inventory records consumed by flake composition.
- `modules/*/imports.nix`: explicit module manifests (no recursive auto-import).
- `agents/`: repo-owned AI agent definitions, skills, MCP servers, presets, and target assets.
- `flake/`: split flake concern files (`apps.nix`, `packages.nix`, `deploy.nix`, `checks.nix`, `overlays.nix`).

## Getting Started

- Install Nix: `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --determinate`
- Clone: `git clone git@github.com:kirksw/nix-config.git`
- Install pre-commit hooks: `nix run .#install-hooks`
- Validate: `nix flake check --no-build`
- macOS build/switch: `apps/aarch64-darwin/build` / `apps/aarch64-darwin/switch`
- Linux switch: `apps/x86_64-linux/switch <hostname>`

## Daily Commands

- Update flake inputs: `nix flake update`
- Update custom packages: `nix run .#update-packages`
- Sync generated agent assets: `nix run .#sync-agents`
- Check structure rules: `./scripts/check-structure.sh`

## Conventions

- Home module options: `homeModules.<name>.enable`
- Darwin module options: `darwinModules.<name>.enable`
- NixOS module options: `nixosModules.<name>.enable`
- Multi-word option names use `camelCase` (example: `homeModules.aiDev.enable`).

## Notes

- `deploy` is intentionally retained as a custom flake output for `deploy-rs` compatibility.
- `nix flake check` may print `unknown flake output 'deploy'`; this warning is expected.
- `nix-agents` is consumed as the reusable generator/wrapper library; concrete agent configuration lives in `agents/`.
- Work-only backend engineering practices are exposed through the `lunar-skills` MCP server and loaded on demand.
