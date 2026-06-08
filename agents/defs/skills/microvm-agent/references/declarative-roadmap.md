# Declarative Roadmap

## Current State (Phase 1)

VMs are managed imperatively via shell scripts on the hypervisor host. The scripts wrap `microvm.nix` commands and QEMU directly. This is the fastest way to get started and allows dynamic VM creation without rebuilding the host.

## Planned State (Phase 2)

VMs are defined as NixOS modules under `hosts/nixos/ry4a/vms/` and built into the host config:

```nix
# hosts/nixos/ry4a/vms/work-agent-1.nix
{ self, config, ... }:
{
  microvm.vms."work-agent-1" = {
    autostart = true;
    config = {
      imports = [ ../../../modules/shared ../../../modules/nixos ];

      microvm = {
        hypervisor = "qemu";
        mem = 4096;
        vcpu = 2;
        shares = [{
          source = "/var/lib/microvms/work-agent-1/data";
          mountPoint = "/data";
          tag = "data";
          proto = "virtiofs";
        }];
      };

      networking.hostName = "work-agent-1";
      services.tailscale.enable = true;
      # ... agent-specific config
    };
  };
}
```

Benefits:
- VM definitions are version-controlled alongside the host config.
- `nixos-rebuild switch` on the host applies VM changes.
- `microvm.autostart` controls which VMs start on boot.

## Migration Path

1. Convert each imperative VM's `config.nix` into a `microvm.vms` entry.
2. Move the config files under `hosts/nixos/ry4a/vms/` in this repo.
3. Import them from the host's `default.nix`.
4. Replace management scripts with wrappers around `systemctl start/stop microvm@<name>`.
5. Remove the imperative scripts from the host.

## Blockers

- Need to decide how per-VM tailscale auth keys are managed in the declarative path.
- Need to test `microvm.vms` with `qemu` hypervisor on this hardware.
- Need to validate that nix builds on the host have enough RAM during builds with concurrent VMs.
