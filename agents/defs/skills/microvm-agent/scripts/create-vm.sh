#!/usr/bin/env bash
# create-vm.sh — create a new microvm on this host
set -euo pipefail

# Defaults
NAME=""
CPUS=2
RAM=4096
DISK=20
EPHEMERAL=false
VM_BASE="/var/lib/microvms"

usage() {
  echo "Usage: $0 --name <name> [--cpus <N>] [--ram <MB>] [--disk <GB>] [--ephemeral]"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --cpus) CPUS="$2"; shift 2 ;;
    --ram)  RAM="$2"; shift 2 ;;
    --disk) DISK="$2"; shift 2 ;;
    --ephemeral) EPHEMERAL=true; shift ;;
    *) usage ;;
  esac
done

[[ -z "$NAME" ]] && usage

VM_DIR="${VM_BASE}/${NAME}"

if [[ -d "$VM_DIR" ]]; then
  echo "ERROR: VM '${NAME}' already exists at ${VM_DIR}" >&2
  exit 1
fi

# Validate name (alphanumeric, dashes, no spaces)
if [[ ! "$NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
  echo "ERROR: VM name must be lowercase alphanumeric with dashes" >&2
  exit 1
fi

echo "Creating VM: ${NAME}"
echo "  CPUs: ${CPUS}"
echo "  RAM:  ${RAM} MB"
echo "  Disk: ${DISK} GB"
echo "  Type: $([ "$EPHEMERAL" = true ] && echo 'ephemeral' || echo 'persistent')"

mkdir -p "$VM_DIR"

# Generate NixOS config for this VM
cat > "$VM_DIR/config.nix" <<EOF
{ pkgs, lib, config, ... }:

{
  microvm = {
    hypervisor = "qemu";
    mem = ${RAM};
    vcpu = ${CPUS};
    interfaces = [{
      type = "tap";
      id = "vm-${NAME}";
    }];
    shares = [{
      source = "${VM_DIR}/data";
      mountPoint = "/data";
      tag = "data";
      proto = "virtiofs";
    }];
  };

  networking.hostName = "${NAME}";
  networking.useDHCP = true;

  services.openssh.enable = true;
  services.tailscale.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [];

  environment.systemPackages = with pkgs; [
    neovim
    git
    curl
    htop
  ];

  system.stateVersion = "25.05";
}
EOF

mkdir -p "$VM_DIR/data"

# Create disk image
${QEMU:-qemu-img} create -f qcow2 "$VM_DIR/disk.qcow2" "${DISK}G"

echo "VM '${NAME}' created at ${VM_DIR}"
echo "Edit ${VM_DIR}/config.nix to customize, then build with:"
echo "  manage-vm.sh build ${NAME}"
