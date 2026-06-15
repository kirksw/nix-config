# feat-add-pi-ponytail-extension

> Add the Ponytail Pi package to generated Pi settings.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Ponytail ships a Pi package that provides an extension plus supporting skills. This repo already manages selected Pi packages through `agents/external/pi-packages/` and feeds them into generated Pi `settings.json`. Ponytail should be added through that same path so personal and work Pi profiles pick it up declaratively.

## Plan

### Scope

- `agents/external/pi-packages/default.nix`
- `agents/external/pi-packages/registry.nix`
- `agents/external/pi-packages/README.md`
- `docs/agents/feat-add-pi-ponytail-extension.md`

### Approach

1. Confirm Ponytail's Pi install source and package manifest shape.
2. Extend the local Pi package registry helper so entries can emit either npm refs or pinned git refs.
3. Add Ponytail as an enabled registry entry using a pinned git ref.
4. Validate that generated Pi settings include the Ponytail package ref.

### Risks

- Ponytail is currently installed from Git rather than the Pi package gallery, so the repo must pin a stable commit or tag explicitly.
- First package install/sync on a machine will require Git/network access for Pi to reconcile the package.

## Testing

Commands run to validate:

```sh
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.fromJSON flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/pi/bases/personal/settings/settings.json".text'
nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in builtins.fromJSON flake.darwinConfigurations.lunar.config.home-manager.users.kisw.xdg.configFile."nix-agents/pi/bases/work/settings/settings.json".text'
./scripts/check-structure.sh
nix flake check --no-build
```

## Summary

### What changed

- Extended `agents/external/pi-packages/default.nix` so the local Pi package registry can emit either pinned npm refs or pinned git refs.
- Added a `ponytail` registry entry in `agents/external/pi-packages/registry.nix` using the upstream Git install source pinned to commit `687c1b339872289d70f65c5eaabce850b1663867`.
- Updated `agents/external/pi-packages/README.md` to document git-backed package entries.
- Synced local Pi settings and installed Ponytail for the active personal Pi profile.

### What was tested

- `nix eval --impure --json --expr 'let flake = builtins.getFlake (toString ./.); in (import ./agents/external/pi-packages/default.nix { lib = flake.inputs.nixpkgs.lib; }).packageRefs'`
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- Verified generated store-backed Pi base settings include the Ponytail git ref:
  - `/nix/store/n30c01gjzkxz2x9iikhhyb8qscp9jr1j-nix-agents-pi-personal-base-settings/settings.json`
  - `/nix/store/1z6paina62wns54dlfm0x58vvm1jmkfb-nix-agents-pi-work-base-settings/settings.json`
- `pi update --extensions`

### Follow-up

- None.
