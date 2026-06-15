# Homelab Topology

## Hosts

### `nixos-ry4a`

- Role: microVM hypervisor host
- Source files:
  - `hosts/nixos/ry4a/default.nix`
  - `hosts/nixos/ry4a/agent-microvms.nix`
  - `modules/nixos/generic/microvm-host.nix`
- Notes:
  - Enables the `microvm-host` module.
  - Carries declarative assistant microVMs via `microvm.vms`.
  - Tailscale is the normal remote-access path.

### `nixos-ry6a`

- Role: primary k3s server
- Source files:
  - `hosts/nixos/ry6a/default.nix`
  - `modules/nixos/generic/k3s.nix`
- Notes:
  - Bootstraps the cluster with `clusterInit = true`.
  - Also owns dashboard TLS rotation and Cloudflare tunnel config.

### `nixos-ry6b`

- Role: k3s agent config target
- Source files:
  - `hosts/nixos/ry6b/configuration.nix`
  - `modules/nixos/generic/k3s.nix`
- Notes:
  - Configured as a k3s agent joining `nixos-ry6a`.
  - `deploy.nix` currently comments this node out because the hardware is broken.

## Deployment Surface

Remote activation is defined in `flake/deploy.nix` for:

- `nixos-ry4a`
- `nixos-ry4a-ts`
- `nixos-ry6a`
- `nixos-ry6a-ts`

Use this deploy mapping when the task is "apply config to the homelab" rather than merely evaluate it.

## Cluster Access

Local Kubernetes tooling is wired by `modules/home/programs/devops.nix`.
It merges repo-managed kubeconfig sources into `~/.kube/config` and exports `KUBECONFIG` there.

Use local `kubectl`, `k9s`, `helm`, and `flux` tooling for cluster inspection after host-side changes land.
