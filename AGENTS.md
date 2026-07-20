# Repository Guide

This is a Nix flake mono-repo for macOS (`nix-darwin`) and Linux (`NixOS`).

## Map

- `flake.nix`, `flake/`: composition and host inventory.
- `hosts/`: host implementations.
- `modules/`: reusable Darwin, Home Manager, NixOS, and shared modules.
- `config/`, `packages/`, `overlays/`: managed configuration, packages, and overlays.
- `apps/<system>/`: build, switch, and rollback wrappers.
- `agents/`: source-of-truth agent definitions, skills, MCPs, presets, profiles, and Pi assets.
- `secrets/`: SOPS-encrypted secrets only.
- `docs/README.md`: architecture, decisions, plans, references, and backlog index.
- `scripts/check-structure.sh`: module manifest and namespace guard.

## Guidance

- [Nix flake operations, validation, and deployment](docs/agents/nix-flake-ops.md)
- [Nix coding style](docs/agents/nix-coding-style.md)
- [Nix module workflow](docs/agents/nix-module-workflow.md)
- [Agent feature workflow](docs/agents/README.md#agent-feature-workflow)
- [Backlog process](docs/BACKLOG.md#process)

## Critical Guardrails

- Never commit plaintext secrets; use `sops` and validate `.sops.yaml` rules.
- Keep module options under `homeModules.*`, `darwinModules.*`, or `nixosModules.*`; use camelCase for multi-word options.
- Treat `agents/` and repository configuration as source of truth; do not edit generated files under `~/.config/nix-agents`.
- **macOS → Linux:** do not use `apps/x86_64-linux/switch` for remote Linux deployment. Use the repository's deploy-rs output with remote builds (`flake/deploy.nix`, `remoteBuild = true`), e.g. `deploy .#nixos-ry6a`; see the operations guide for details.
- If an agent workflow or process fails, tell or prompt the user to add, change, or fix repository documentation or guardrails so the failure is less likely to recur. Before recommending that documentation or guardrail change, ask a read-only subagent to validate that it would have prevented or resolved the issue, and report the validation result. Documentation does not replace code fixes where enforcement is appropriate; make both changes when needed.
- The custom `deploy` flake output may produce an `unknown flake output 'deploy'` warning during checks; this is expected.
