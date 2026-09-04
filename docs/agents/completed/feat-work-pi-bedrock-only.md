# feat-work-pi-bedrock-only

> Drop the direct Anthropic provider from work Pi profiles and use Amazon Bedrock exclusively for Claude models.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Work Claude access now routes exclusively through Amazon Bedrock (AWS profile `lw-employee-ai`, `eu-west-1`, already exported in work env). The work Pi profiles still carry direct `anthropic/*` tier entries, bare `claude-*` enabled models, and an Anthropic OAuth entry in `piWorkAuth`. These are dead weight and show unusable models in the picker, so remove them and keep only `amazon-bedrock/*` ids. Personal profiles are unaffected.

## Plan

### Scope

- `agents/presets/profiles.nix`: tier S/A/B/E Claude entries in `work-default` and `work-full`.
- `agents/presets/factory.nix`: tier S/A/B/E Claude entries in `work-factory`.
- `agents/base-settings.nix`: `piWorkModelDefaults.enabledModels` and `piWorkAuth`.

### Approach

1. Replace each direct tier entry with its Bedrock eu-region equivalent from the pi-ai 0.84.4 catalog:
   - `anthropic/claude-fable-5` → `amazon-bedrock/eu.anthropic.claude-fable-5`
   - `anthropic/claude-opus-4-8` → `amazon-bedrock/eu.anthropic.claude-opus-4-8`
   - `anthropic/claude-sonnet-4-6` → `amazon-bedrock/eu.anthropic.claude-sonnet-4-6`
   - `anthropic/claude-haiku-4-5-20251001` → `amazon-bedrock/eu.anthropic.claude-haiku-4-5-20251001-v1:0`
2. In `piWorkModelDefaults.enabledModels`, drop the bare `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-opus-5`, `claude-sonnet-5` entries and add the two new Bedrock ids so every tier member is pickable.
3. Remove the `anthropic` OAuth entry from `piWorkAuth`; Bedrock auth stays AWS-credential based.
4. Keep OpenAI models and existing Bedrock entries untouched.

### Risks

- `eu.anthropic.claude-fable-5` and `eu.anthropic.claude-sonnet-4-6` must be entitled in the `lw-employee-ai` AWS account; if not, the tier chain falls back to the next entry.
- Removing the OAuth entry logs out direct Anthropic access in work bases; reverting requires re-auth.
- The anthropic-communication-policy extension already matches Bedrock identifiers, so no change needed there.

## Testing

Commands run to validate:

```sh
nixfmt --check agents/presets/profiles.nix agents/presets/factory.nix agents/base-settings.nix
git diff --check
./scripts/check-structure.sh
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
```

Result: all commands passed. `nix flake check --no-build` needed the changed `agents-src` derivation realized first (IFD under `--no-build`); after `nix eval .#apps.aarch64-darwin.sync-agents.program` it passed cleanly. Sync regenerated work, work-full, and work-factory assets. Stale `anthropic` keys were also removed from the seeded-mutable `settings/auth.json` and runtime `state/auth.json` in work and work-full bases, since `seed_mutable_file` preserves target-only keys.

## Summary

### What changed

- Work Pi profiles (`work-default`, `work-full`, `work-factory`) now use `amazon-bedrock/eu.anthropic.*` tier entries exclusively: fable-5 (S), opus-4-8 (A), sonnet-4-6 (B), haiku-4-5-20251001-v1:0 (E).
- `piWorkModelDefaults.enabledModels` drops bare `claude-*` ids and gains `eu.anthropic.claude-fable-5` and `eu.anthropic.claude-sonnet-4-6` so every tier member is pickable.
- `piWorkAuth` no longer seeds the Anthropic OAuth entry; Bedrock auth remains AWS-credential based (`AWS_PROFILE=lw-employee-ai`, `eu-west-1`).
- Removed leftover `anthropic` keys from work base `settings/auth.json` and `state/auth.json` runtime files (effective logout of direct Anthropic).

### What was tested

- `nixfmt --check`, `git diff --check`, `check-structure.sh`, `nix flake check --no-build --no-eval-cache` pass.
- `nix run .#sync-agents` regenerated all bases; verified generated work manifests contain only `amazon-bedrock/eu.anthropic.*` Claude ids and no direct `anthropic/claude` ids; work settings.json has no bare `claude-*` models; auth files now hold only `openai` (plus unrelated runtime `azure-openai-responses` state key).

### Follow-up

- None. If `eu.anthropic.claude-fable-5` or `claude-sonnet-4-6` are not entitled in `lw-employee-ai`, those tier slots fall back to the next chain entry.
