#!/usr/bin/env bash
# manage-vm.sh — start, stop, restart, remove, or build a microvm
set -euo pipefail

VM_BASE="/var/lib/microvms"

usage() {
  echo "Usage: $0 <start|stop|restart|remove|build> <name>"
  exit 1
}

[[ $# -lt 2 ]] && usage

ACTION="$1"
NAME="$2"
VM_DIR="${VM_BASE}/${NAME}"

check_exists() {
  if [[ ! -d "$VM_DIR" ]]; then
    echo "ERROR: VM '${NAME}' does not exist" >&2
    exit 1
  fi
}

case "$ACTION" in
  start)
    check_exists
    if systemctl is-active "microvm@${NAME}" &>/dev/null; then
      echo "VM '${NAME}' is already running"
      exit 0
    fi

    # Check for ephemeral marker
    if [[ -f "$VM_DIR/.ephemeral" ]]; then
      echo "Ephemeral VM: recreating disk..."
      DISK_SIZE="$(qemu-img info --output=json "$VM_DIR/disk.qcow2" 2>/dev/null | ${JQ:-jq} -r '.["virtual-size"]' 2>/dev/null || echo "21474836480")"
      rm -f "$VM_DIR/disk.qcow2"
      ${QEMU:-qemu-img} create -f qcow2 "$VM_DIR/disk.qcow2" "$((DISK_SIZE / 1073741824))G"
    fi

    echo "Starting VM '${NAME}'..."
    systemctl start "microvm@${NAME}"
    echo "VM '${NAME}' started"
    ;;

  stop)
    check_exists
    if ! systemctl is-active "microvm@${NAME}" &>/dev/null; then
      echo "VM '${NAME}' is already stopped"
      exit 0
    fi

    echo "Stopping VM '${NAME}'..."
    systemctl stop "microvm@${NAME}"

    # Clean up ephemeral disk
    if [[ -f "$VM_DIR/.ephemeral" ]]; then
      echo "Ephemeral VM: removing disk..."
      rm -f "$VM_DIR/disk.qcow2"
    fi

    echo "VM '${NAME}' stopped"
    ;;

  restart)
    check_exists
    echo "Restarting VM '${NAME}'..."
    systemctl restart "microvm@${NAME}"
    echo "VM '${NAME}' restarted"
    ;;

  remove)
    check_exists
    echo "WARNING: This will permanently delete VM '${NAME}' and all its data."

    # Stop if running
    if systemctl is-active "microvm@${NAME}" &>/dev/null; then
      echo "Stopping running VM..."
      systemctl stop "microvm@${NAME}"
    fi

    rm -rf "$VM_DIR"
    echo "VM '${NAME}' removed"
    ;;

  build)
    check_exists
    if [[ ! -f "$VM_DIR/config.nix" ]]; then
      echo "ERROR: No config.nix found in ${VM_DIR}" >&2
      exit 1
    fi

    echo "Building VM '${NAME}'..."
    (
      cd "$VM_DIR"
      nix-build '<nixpkgs/nixos>' -A microvm \
        --arg configuration ./config.nix \
        -o result
    )
    echo "VM '${NAME}' built: ${VM_DIR}/result"
    ;;

  *)
    usage
    ;;
esac
