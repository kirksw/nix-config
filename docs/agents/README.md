# Agent Documentation Index

Executable skills under [`agents/defs/skills/`](../../agents/defs/skills/) are the canonical operational guidance. The pages below are stable repository-facing links; do not duplicate skill bodies here.

- [Nix coding style](./nix-coding-style.md)
- [Nix flake operations](./nix-flake-ops.md)
- [Nix module workflow](./nix-module-workflow.md)
- [Secrets management](./secrets-management.md)
- [Feature-plan template](./TEMPLATE.md)
- [`completed/`](./completed/) contains completed feature plans and validation history.

## Agent Feature Workflow

Every agent-related change follows this plan → implement → test → complete workflow:

1. Create `docs/agents/feat-<name>.md` from [`TEMPLATE.md`](./TEMPLATE.md), documenting context, scope, approach, risks, and Definition of Done.
2. Implement the agent, skill, MCP, preset, profile, extension, hook, flake app, or module change.
3. Run the relevant commands in [Nix flake operations](./nix-flake-ops.md), plus targeted builds or smoke checks; record results in the plan.
4. Fill in the plan summary and move it to [`completed/`](./completed/).
5. Add a [`docs/BACKLOG.md`](../BACKLOG.md) item only for unfinished follow-up work, with priority, effort, description, and source. Do not add a placeholder item when the work is complete.

Generated assets are synced into local profile roots at runtime. The repository source remains `agents/`; work-only backend practices are exposed through the `lunar-skills` MCP server, and `sync-work-skills` is legacy/manual only.
