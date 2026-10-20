# Validate and sync

Read `../references/flake-ops.md` for the full runbook and host/deployment cautions.

1. Run targeted formatting and structure checks (`nixfmt --check <changed .nix files>` and `./scripts/check-structure.sh`).
2. Run `nix flake check --no-build` for repository changes. For Pi assets, also run `nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link`.
3. Inspect the diff and verify the selected skills and configuration in the built output.
4. For agent-only rollout, verify the `sync-agents` flake app exists, then run `nix run .#sync-agents` and inspect synced profiles. Restart active agent sessions to load new skills.

Do not deploy a host to validate only an agent skill; use host build checks if machine configuration changed.
