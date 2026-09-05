# feat-gpt56-down-one-tier

> Move every GPT-5.6 model down one capability tier across personal, work, and factory profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

GPT-6 Astra and newer Bedrock Claude models now occupy the highest profile tiers.
GPT-5.6 Sol, Terra, and Luna should each move down exactly one tier across all profiles so tier selection reflects the revised capability ordering.

## Plan

### Scope

- `agents/presets/profiles.nix`: `personal-default`, `personal-full`, `work-default`, and `work-full`.
- `agents/presets/factory.nix`: `home-factory` and `work-factory`.
- Generated manifests for all six profiles.

### Approach

1. Move GPT-5.6 Sol from tier S to the head of tier A.
2. Move GPT-5.6 Terra from tier A to the head of tier B.
3. Move GPT-5.6 Luna from tier B to the head of tier C.
4. Preserve the relative order of every other model and leave enabled-model lists unchanged.
5. Remove the `home-factory` tier S override because it has no higher-tier model configured; tier mappings reject empty lists.

### Risks

- Tier-based agents will use different default models and fallback chains.
- `home-factory` no longer explicitly configures tier S; generators may use their target-specific default if an agent requests an unmapped S tier.

## Testing

Commands run to validate:

```sh
nixfmt --check agents/presets/profiles.nix agents/presets/factory.nix
./scripts/check-structure.sh
git diff --check
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
```

## Summary

### What changed

- Moved GPT-5.6 Sol from tier S to tier A, Terra from A to B, and Luna from B to C in all personal, work, and factory profiles.
- Preserved the relative fallback order of all non-GPT-5.6 models.
- Removed the `home-factory` S override because the tier would otherwise be empty and tier mappings require non-empty values.
- Included the pending Bedrock EU Opus 5 tier A entries in all work profiles.

### What was tested

- `nixfmt --check`, `git diff --check`, `./scripts/check-structure.sh`, and `nix flake check --no-build --no-eval-cache` pass.
- `nix run .#sync-agents` regenerated all profiles.
- Verified generated manifests for `personal-default`, `personal-full`, `work-default`, `work-full`, `home-factory`, and `work-factory`: Sol is only in A, Terra only in B, and Luna only in C.

### Follow-up

- None.
