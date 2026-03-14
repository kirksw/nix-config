# Nix Flake Operations

Use this skill for building, testing, and applying system configuration changes.

## Build Commands

- `apps/aarch64-darwin/build` - Build macOS generation without switching
- `apps/aarch64-darwin/switch` - Build and apply macOS config (requires sudo)
- `apps/aarch64-darwin/rollback` - Rollback to previous macOS generation
- `apps/x86_64-linux/switch <host>` - Apply Linux host config (example: `apps/x86_64-linux/switch nixos-ry6a`)

## Validation Commands

- `nix flake check` - Run all flake checks (including deploy checks)
- `nix flake check --no-build` - Fast validation without building
- `./scripts/check-structure.sh` - Validate module structure and naming conventions
- `nix build .#<package-name>` - Build specific package

## Update Commands

- `nix flake update` - Update all lockfile inputs
- `nix flake update <input>` - Update specific input (example: `nix flake update nixpkgs`)
- `nix run .#update-packages` - Run package update scripts for custom packages

## Apply Changes

After successful build, apply with:
- macOS: `sudo apps/aarch64-darwin/switch <hostname>`
- Linux: `apps/x86_64-linux/switch <hostname>`

## Common Issues

- **unknown flake output 'deploy'**: This is expected - deploy-rs uses a custom output
- **Build fails**: Run `nix flake check --no-build` first for fast feedback
- **Module not found**: Ensure it's imported in `modules/home/imports.nix`
- **Option not found**: Check the module is properly imported and enabled

## Quick Validation Loop

```bash
# Fast check
nix flake check --no-build

# Build
apps/aarch64-darwin/build <hostname>

# Apply (requires sudo on macOS)
sudo apps/aarch64-darwin/switch <hostname>
```
