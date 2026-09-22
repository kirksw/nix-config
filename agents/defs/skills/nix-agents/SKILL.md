---
name: nix-agents
description: Repository workflow for Nix coding style, module definitions, and flake operations. Use when writing or reviewing Nix code in this repo, adding or modifying skills, profiles, or Pi target assets, building generated configs, syncing local tool configs, or running validation commands.
---

# Repo Nix Workflow

Use this skill for all repo-specific Nix work in `nix-config`.

## Read These References As Needed

- `references/coding-style.md`: formatting, linting, and common Nix patterns used here
- `references/module-workflow.md`: module shapes, repository layout, and wiring rules
- `references/flake-ops.md`: build, check, sync, and target-specific commands
- `references/failure-triage.md`: known Nix failure signatures and first recovery actions

## Working Rules

- Follow the repo's Nix style before changing `.nix` files.
- Use the module workflow reference when adding or rewiring skills and profiles.
- Use the flake ops reference when validating or syncing changes.
- For Nix failures, read the failure triage reference before changing code.
- Treat Nix daemon/socket permission errors as sandbox access problems until reproduced with normal Nix access.
- Verify actual flake apps before running documented sync commands; prefer `sync-agents` for agent-only rollout.
