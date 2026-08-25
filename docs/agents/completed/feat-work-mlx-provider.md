# feat-work-mlx-provider

> Expose the local MLX Qwen model in both work Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The `mlx-dspark/Qwen3-8B-4bit` model was available only in personal Pi profiles.
Projects that select `work-default` or `work-full` could not use the explicitly started local server.

## Plan

### Scope

Change `agents/base-settings.nix` so the work and personal model files share one local provider definition.
Update the targeted provider check in `flake.nix` to cover both work profiles and preserve factory isolation.

### Approach

1. Extract the existing MLX provider configuration into a shared Nix value.
2. Include that provider in the generated work models alongside the work OpenAI override.
3. Validate repository structure, flake evaluation, generated profile synchronization, and both work profile model lists.

### Risks

The provider remains unavailable when its explicitly managed server is not running.
The local provider must not depend on AWS credentials.

## Testing

Commands run to validate:

```sh
nixfmt --check agents/base-settings.nix flake.nix
git diff --check
./scripts/check-structure.sh
nix flake check --no-build
nix build .#checks.aarch64-darwin.pi-mlx-dspark-provider --no-link --print-build-logs
nix run .#sync-agents
nix build .#pi --no-link --print-out-paths
# Ran the built Pi binary with each generated work profile and --list-models mlx-dspark.
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Reused one `mlx-dspark` provider definition in personal, work-default, and work-full model files.
- Kept work-factory unchanged and without the local provider.
- Extended the provider check to validate both work profiles and factory isolation.

### What was tested

- Repository structure and full flake evaluation passed.
- The targeted provider check built successfully.
- Generated configurations were synchronized locally.
- The built Pi binary listed `mlx-dspark/Qwen3-8B-4bit` under work-default and work-full.

### Follow-up

- None.
