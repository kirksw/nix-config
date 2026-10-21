# Onboard a macOS host

1. Inspect the target's macOS version, architecture, existing accounts and UIDs, Nix installation, `/etc/nix/nix.custom.conf`, developer tools, SSH access, and power settings before changing it.
2. Register the host in `flake/hosts/darwin/default.nix`, add its inventory in `flake/hosts/darwin/<host>.nix`, and define host and Home Manager modules under `hosts/darwin/`.
3. For a new Home Manager target user, declare a unique UID and include it in `users.knownUsers` so nix-darwin creates the account before Home Manager activates.
   Do not put an existing administrator in `users.knownUsers`.
4. Run `./scripts/check-structure.sh`, `nix flake check --no-build`, and `nix build .#darwinConfigurations.<host>.config.system.build.toplevel --no-link` before switching.
5. On a fresh Determinate Nix install, `/etc/nix/nix.custom.conf` may be a regular installer-owned file.
   If nix-darwin refuses to overwrite it, inspect and preserve it as `/etc/nix/nix.custom.conf.before-nix-darwin`, then retry the switch; do not replace it without inspection.
6. Switch on the target with the built host's `darwin-rebuild switch --flake .#<host>` and verify the hostname, account, tools, and SSH access.
   The existing `apps/aarch64-darwin/switch` wrapper is specific to the YubiKey/Lunar host and is not suitable for a new headless host.
