# Deploy And Verify

## Fast Validation

Run these first for nearly every homelab change:

```sh
./scripts/check-structure.sh
nix flake check --no-build
```

Then add a targeted eval or dry-run build for the host you touched:

```sh
nix build .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel --no-link --dry-run
nix build .#nixosConfigurations.nixos-ry6a.config.system.build.toplevel --no-link --dry-run
nix eval .#nixosConfigurations.nixos-ry4a.config.microvm.autostart --json
```

Use `nix eval` when you need to inspect one option or derived value without building.

## Deploy

Use the flake's deploy-rs output for remote activation when the target host is available:

```sh
deploy .#nixos-ry4a
deploy .#nixos-ry6a
```

Tailnet alternatives also exist:

```sh
deploy .#nixos-ry4a-ts
deploy .#nixos-ry6a-ts
```

Only deploy the hosts affected by the change.

## Post-Deploy Verification

Choose the smallest verification that proves the change landed.

### Host-level

```sh
ssh root@nixos-ry4a -- systemctl status microvm@personal-assistant --no-pager
ssh root@nixos-ry6a -- systemctl status k3s --no-pager
```

### Cluster-level

```sh
kubectl get nodes -o wide
kubectl get pods -A
```

For service-specific changes, inspect only the impacted namespace or workload instead of scanning the entire cluster.

## Decision Guide

- Changed `hosts/nixos/ry4a/**` or `modules/nixos/generic/microvm-host.nix` -> validate/build `nixos-ry4a`, then verify microVM state.
- Changed `hosts/nixos/ry6a/**` or `modules/nixos/generic/k3s.nix` -> validate/build `nixos-ry6a`, then verify k3s and any affected namespaces.
- Changed shared Nix modules used by multiple homelab hosts -> build every impacted host before deploy.
- Changed only Kubernetes resources external to this repo -> use cluster tooling, not host deploy commands.
