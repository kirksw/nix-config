# Architecture

This file is the top-level map of the repository. Detailed guidance and decision
history live in the [documentation index](./docs/README.md).

## System Boundaries

| Area | Source of truth | Responsibility |
| --- | --- | --- |
| Flake composition | `flake.nix`, `flake/` | Inputs, host inventory, and output wiring |
| Host configuration | `hosts/` | Host-specific Darwin and NixOS configuration |
| Reusable configuration | `modules/` | Shared Darwin, Home Manager, and NixOS modules |
| User configuration | `config/` | Program configuration linked by modules |
| Packages and overlays | `packages/`, `overlays/` | Locally maintained packages and nixpkgs extensions |
| Operations | `apps/`, `scripts/` | Build, switch, rollback, update, and validation entry points |
| Agent configuration | `agents/` | Agent, skill, MCP, preset, profile, and target definitions |
| Secrets | `secrets/`, `.sops.yaml` | Encrypted secret material and creation rules |

## Composition Flow

1. `flake.nix` imports the output modules under `flake/`.
2. `flake/hosts/` declares each host and points to its implementation under `hosts/`.
3. Hosts enable reusable modules from `modules/`.
4. Modules install packages and link program configuration from `config/`.
5. System-specific wrappers under `apps/<system>/` build or apply the result.

## Architectural Constraints

- Keep host-specific choices in `hosts/`; move reusable behavior into `modules/`.
- Module options use the `homeModules`, `darwinModules`, or `nixosModules` namespace.
- Agent definitions are authored in `agents/`; generated profile output is not a source of truth.
- Secrets remain SOPS-encrypted and are referenced declaratively.
- Repository invariants are enforced by `scripts/check-structure.sh` and flake checks.

## Further Reading

- [Design catalog](./docs/design/README.md)
- [Core beliefs](./docs/design/core-beliefs.md)
- [Architecture decisions](./docs/adrs/)
- [Execution plans](./docs/plans/README.md)
- [Agent engineering guides and plans](./docs/agents/README.md)
- [Technical-debt backlog](./docs/BACKLOG.md)
