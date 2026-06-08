# VM Lifecycle

## Directory Layout

Each VM lives under `/var/lib/microvms/<name>/`:

```
/var/lib/microvms/<name>/
  disk.qcow2        # VM disk image (20 GB default, thin provisioned)
  config.nix        # NixOS configuration for this VM
  result -> /nix/store/...  # Built VM profile symlink
  state             # microvm.nix runtime state
```

## Creation (create-vm.sh)

1. Create the VM directory under `/var/lib/microvms/<name>/`.
2. Generate a NixOS config from a template:
   - Sets hostname to the VM name.
   - Configures tailscale with the provided auth key.
   - Sets vCPUs and RAM via microvm options.
   - Enables SSH with key-based auth.
3. Build the VM: `nix-build '<nixpkgs/nixos>' -A microvm --arg configuration ./config.nix`.
4. Create the qcow2 disk image: `qemu-img create -f qcow2 disk.qcow2 <size>`.
5. Register the VM with microvm.nix.

## Start (manage-vm.sh start)

1. Check the VM exists and is not already running.
2. If ephemeral: recreate the disk image from scratch.
3. Start via `microvm.nix` runtime: `systemctl start microvm@<name>`.
4. Wait for tailscale to come up (poll `tailscale status`).

## Stop (manage-vm.sh stop)

1. Graceful shutdown via `systemctl stop microvm@<name>`.
2. If ephemeral: delete the disk image.

## Remove (manage-vm.sh remove)

1. Stop the VM if running.
2. Delete `/var/lib/microvms/<name>/` entirely.
3. Remove any nix store builds that are only referenced by this VM.

## Tailscale Integration

Each VM runs its own tailscale daemon. The auth key determines whether the VM's identity persists:

- **Reusable key** (tailscale `--authkey`): VM retains its tailnet IP across restarts. Use for persistent VMs.
- **Ephemeral key** (tailscale `--authkey --ephemeral`): VM gets a new identity each start. Use for ephemeral VMs.

The key should be stored in SOPS and passed to the VM config. For the host's SOPS setup, see the `secrets-management` skill.
