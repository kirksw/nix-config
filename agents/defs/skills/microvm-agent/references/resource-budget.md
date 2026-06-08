# Resource Budget

## Host: nixos-ry4a

| Resource | Total | Reserved for host | Available for VMs |
|---|---|---|---|
| CPU cores | 8 | 2 | 6 |
| RAM | 32768 MB | 8192 MB | 24576 MB |
| Disk | depends on hardware | 50 GB | rest |

## Default VM Allocation

| Resource | Default |
|---|---|
| vCPUs | 2 |
| RAM | 4096 MB |
| Disk | 20 GB |

## Example Configurations

### 6 identical VMs (default)
- 6 × 2 vCPU = 12 vCPUs (overcommit is fine, VMs are not all CPU-bound)
- 6 × 4 GB = 24 GB RAM (exactly the available budget)
- 6 × 20 GB = 120 GB disk

### 4 agent VMs (balanced)
- 2 × 4 vCPU, 8192 MB — heavy agents (e.g., long-running coding agents)
- 2 × 2 vCPU, 4096 MB — light agents (e.g., monitoring, git sync)

### Mixed persistent + ephemeral
- 2 persistent VMs at 4 vCPU / 8 GB each = 16 GB
- 2 ephemeral VMs at 2 vCPU / 4 GB each = 8 GB
- Total: 24 GB (fits budget with 8 GB host headroom)

## Guidelines

- **Overcommit CPUs** freely — agents are I/O bound, not CPU bound. 2× overcommit is safe.
- **Do not overcommit RAM** — QEMU allocates real memory. Exceeding physical RAM causes OOM kills.
- **Leave 8 GB for the host** — the host runs libvirtd, tailscale, SSH, and nix builds.
- **Thin-provisioned disks** — qcow2 only allocates blocks on write. A 20 GB disk may only use 3–5 GB in practice.
