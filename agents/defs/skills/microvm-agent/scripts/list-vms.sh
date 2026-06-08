#!/usr/bin/env bash
# list-vms.sh — list all microvms and their status
set -euo pipefail

VM_BASE="/var/lib/microvms"

[[ -d "$VM_BASE" ]] || { echo "No microvms directory found"; exit 0; }

printf "%-25s %-10s %-6s %-8s %-10s %s\n" "NAME" "STATE" "VCPUS" "RAM(MB)" "DISK(GB)" "TAILSCALE IP"
printf "%-25s %-10s %-6s %-8s %-10s %s\n" "-------------------------" "----------" "------" "--------" "----------" "-------------"

for vm_dir in "$VM_BASE"/*/; do
  [[ -d "$vm_dir" ]] || continue
  name="$(basename "$vm_dir")"

  # Check if running via systemd
  if systemctl is-active "microvm@${name}" &>/dev/null; then
    state="running"
  else
    state="stopped"
  fi

  # Parse config for resources
  vcpus="?"
  ram="?"
  disk="?"
  if [[ -f "$vm_dir/config.nix" ]]; then
    vcpus="$(grep -oP 'vcpu\s*=\s*\K\d+' "$vm_dir/config.nix" 2>/dev/null || echo "?")"
    ram="$(grep -oP 'mem\s*=\s*\K\d+' "$vm_dir/config.nix" 2>/dev/null || echo "?")"
  fi
  if [[ -f "$vm_dir/disk.qcow2" ]]; then
    disk="$(du -sh "$vm_dir/disk.qcow2" 2>/dev/null | cut -f1 || echo "?")"
  fi

  # Get tailscale IP if running
  ts_ip="-"
  if [[ "$state" == "running" ]]; then
    # Try to get IP from the VM's tailscale via the microvm socket or network
    ts_ip="$(timeout 2 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=1 "${name}" "tailscale ip -4 2>/dev/null" 2>/dev/null || echo "-")"
  fi

  printf "%-25s %-10s %-6s %-8s %-10s %s\n" "$name" "$state" "$vcpus" "$ram" "$disk" "$ts_ip"
done
