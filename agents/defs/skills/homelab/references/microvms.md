# MicroVMs On `nixos-ry4a`

## Current Shape

The main declarative microVM definitions live in:

- `hosts/nixos/ry4a/default.nix`
- `hosts/nixos/ry4a/agent-microvms.nix`
- `modules/nixos/generic/microvm-host.nix`

The configured assistant VMs are:

- `sanja-assistant`
- `kirk-assistant`

No LLM router VMs are currently configured.

These are defined declaratively with `microvm.vms` and persistent volumes for assistant state, Tailscale identity, and OpenClaw state.

## What To Change Where

- Hypervisor defaults, storage path, and libvirt/QEMU support -> `modules/nixos/generic/microvm-host.nix`
- Host-specific microVM wiring -> `hosts/nixos/ry4a/default.nix`
- Assistant VM definitions, volumes, auth-key mounts, and autostart -> `hosts/nixos/ry4a/agent-microvms.nix`

## Useful Checks

Local evaluation:

```sh
nix eval .#nixosConfigurations.nixos-ry4a.config.microvm.autostart --json
nix eval .#nixosConfigurations.nixos-ry4a.config.microvm.vms --apply builtins.attrNames --json
```

Remote inspection:

```sh
ssh root@nixos-ry4a -- systemctl list-units 'microvm@*'
ssh root@nixos-ry4a -- systemctl status microvm@kirk-assistant --no-pager
```

## Capacity Notes

The hypervisor host is documented as an 8-core, 32-GB x86_64-linux box. The assistant microVMs currently default to 2 vCPU and 4096 MB RAM each, so large rebuilds or extra VMs need headroom planning.

## Imperative vs Declarative

Prefer declarative `microvm.vms` changes in this repo.
Only use ad hoc host commands for inspection, emergency recovery, or service control after a declarative deployment.
