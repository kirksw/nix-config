# nix-agents Engine / Config Split

`nix-config` owns the concrete agent configuration for this machine. The external `nix-agents`
flake is kept as a reusable engine that can be opened or shared independently.

## Boundary

- `nix-config/agents/`: local source of truth for agents, skills, MCP servers, presets, profiles,
  Pi extensions, and workflow guidance.
- `nix-config/modules/home/programs/ai-agents.nix`: Home Manager integration that builds wrapped
  tools from local modules using `inputs.nix-agents.lib`.
- `nix-agents`: reusable module schema, evaluator, wrappers, target generators, schemas, and
  templates.

## Migration Model

This repo is migrated first so local wrappers no longer depend on opinionated upstream presets.
After that is stable, the follow-up is to slim the upstream `nix-agents` repo down to engine and
template assets only.

## Validation

Use the normal repo validation path after changing local agent configuration:

```sh
./scripts/check-structure.sh
nix flake check --no-build
```

Build relevant package outputs when touching local agent packages:

```sh
```
