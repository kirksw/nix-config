# feat-work-bedrock-eu-opus5

> Add Amazon Bedrock EU Claude Opus 5 to all work Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Work Claude access routes exclusively through Amazon Bedrock in `eu-west-1`.
The shared work enabled-model list already includes `amazon-bedrock/eu.anthropic.claude-opus-5`, but the work tier mappings do not use it.
AWS documents `eu.anthropic.claude-opus-5` as the EU cross-region inference profile ID.

## Plan

### Scope

- `agents/presets/profiles.nix`: tier A in `work-default` and `work-full`.
- `agents/presets/factory.nix`: tier A in `work-factory`.
- Generated work Pi profile manifests.

### Approach

1. Insert `amazon-bedrock/eu.anthropic.claude-opus-5` before Opus 4.8 in tier A for every work profile.
2. Keep Opus 4.8 and the OpenAI models as ordered fallbacks.
3. Keep `piWorkModelDefaults.enabledModels` unchanged because it already includes Opus 5.
4. Sync generated assets and verify that all three work manifests resolve Opus 5 in tier A.

### Risks

- The `lw-employee-ai` AWS account must have access to the EU Opus 5 inference profile.
- Opus 5 becomes the preferred Claude model for tier A and may cost more than Opus 4.8.

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

- Added `amazon-bedrock/eu.anthropic.claude-opus-5` to tier A in `work-default`, `work-full`, and `work-factory`.
- Placed Opus 5 before Opus 4.8 while retaining OpenAI and Opus 4.8 fallbacks.
- Kept the shared enabled-model list unchanged because it already contained the EU Opus 5 ID.

### What was tested

- `nixfmt --check`, `git diff --check`, `./scripts/check-structure.sh`, and `nix flake check --no-build --no-eval-cache` pass.
- `nix run .#sync-agents` regenerated all profiles.
- Verified all three generated work manifests place EU Opus 5 before Opus 4.8 in tier A.
- The installed work Pi wrapper lists `amazon-bedrock/eu.anthropic.claude-opus-5` with a 1M context window, 128K output, reasoning, and image input.

### Follow-up

- None.
