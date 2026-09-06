# MicroVMs On `nixos-ry4a`

## Current Shape

The main declarative microVM definitions live in:

- `hosts/nixos/ry4a/default.nix`
- `hosts/nixos/ry4a/agent-microvms.nix`
- `modules/nixos/generic/microvm-host.nix`

The configured assistant VMs are:

- `sanja-assistant`
- `kirk-assistant`

The interactive agent VM is:

- `personal-agent`

It provides the personal-default Pi profile and a persistent Herdr server that is reachable through SSH with `herdr --remote personal-agent`.
Its home directory, workspace, and Tailscale identity are persistent.
Pi credentials are provisioned manually and remain in the persistent home volume.

No LLM router VMs are currently configured.

These are defined declaratively with `microvm.vms` and persistent volumes for agent state and Tailscale identity.

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
ssh root@nixos-ry4a -- systemctl status microvm@personal-agent --no-pager
herdr --remote personal-agent
```

## Capacity Notes

The hypervisor host is documented as an 8-core, 32-GB x86_64-linux box. The assistant microVMs currently default to 2 vCPU and 4096 MB RAM each, so large rebuilds or extra VMs need headroom planning.

## Imperative vs Declarative

Prefer declarative `microvm.vms` changes in this repo.
Only use ad hoc host commands for inspection, emergency recovery, or service control after a declarative deployment.

## Personal Agent Rollout Acceptance

A host deployment alone does not activate a changed VM because `restartIfChanged` is disabled.
Restart only the intended VM after deployment, then verify its `current` and `booted` runner links match.
Check the running VM's `personal-agent-profile.service` and compare persistent managed profile assets with the generated source referenced by that service.
A matching runner is not sufficient: bootstrap-only wrapper sync can leave old persistent model tiers in place.
Verify the actual `AGENTS.md` tier table and check `systemctl --failed` inside the VM before declaring success.
The reconciliation service owns only the listed managed assets and backs them up under `/home/agent/.local/state/nix-agents/profile-backups`.
Credentials, sessions, workspaces, and user settings must remain unchanged.
