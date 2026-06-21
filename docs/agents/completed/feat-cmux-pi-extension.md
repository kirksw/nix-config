# feat-cmux-pi-extension

> Add cmux to Lunar tooling and install the Pi CMUX extension package.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Lunar work sessions should have the `cmux` CLI available and Pi should load the `gtwatts/pi-cmux` extension package for CMUX-powered workflows.

## Plan

### Scope

- `modules/home/programs/lunar.nix`
- `agents/external/pi-packages/registry.nix`

### Approach

1. Add `cmux` to Lunar home packages.
2. Add `pi-cmux` to the Pi package registry as a pinned GitHub package.
3. Validate formatting and generated Pi package settings.

### Risks

- Pi packages run local extension code with user permissions; only install from trusted sources.
- The GitHub package is pinned to the currently fetched commit and will need an explicit update later.

## Testing

Commands run to validate:

```sh
nixfmt modules/home/programs/lunar.nix agents/external/pi-packages/registry.nix
./scripts/check-structure.sh
nix eval --impure --raw --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; in pkgs.cmux.pname or pkgs.cmux.name'
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "aarch64-darwin"; }; piPackages = import ./agents/external/pi-packages { inherit (pkgs) lib; }; in piPackages.packageRefs'
nix flake check --no-build
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
nix run .#sync-agents
```

## Summary

### What changed

- Added `cmux` to Lunar Home Manager packages.
- Added `pi-cmux` as a pinned GitHub Pi package: `git:github.com/gtwatts/pi-cmux@0b6010b93bd7f2cd29b842dd9f2619b23645356f`.
- Synced live Pi personal/work settings so current profiles include the package ref.

### What was tested

- Nix formatting and repo structure checks.
- Nix eval confirms `pkgs.cmux` exists for `aarch64-darwin`.
- Nix eval confirms generated Pi package refs include `pi-cmux`.
- `nix flake check --no-build`.
- Lunar Darwin toplevel build.
- `nix run .#sync-agents`.

### Follow-up

- None.
