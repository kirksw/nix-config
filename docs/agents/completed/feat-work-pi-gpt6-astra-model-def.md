# feat-work-pi-gpt6-astra-model-def

> Define `gpt-6-astra` in the work Pi OpenAI provider so the enabled-model pattern resolves.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The work Pi profiles enable `gpt-6-astra`, but Pi's bundled OpenAI catalog does not yet contain that model.
Pi consequently warns that no models match the configured pattern.
OpenAI documents the model as `gpt-6-astra`; there is no documented `gpt-5.6-astra` model.

## Plan

### Scope

- `agents/base-settings.nix`: work Pi OpenAI provider model definitions.
- Generated work and work-full Pi profile settings.

### Approach

1. Add the documented `gpt-6-astra` model metadata to `piWorkModels.providers.openai.models`.
2. Keep the work OpenAI EU endpoint and existing enabled-model/tier configuration unchanged.
3. Sync generated profiles and verify that work Pi resolves `openai/gpt-6-astra` without a pattern warning.

### Risks

- The work OpenAI account or EU endpoint may not have server-side access even when Pi can resolve the local model definition.
- Model capabilities and pricing metadata may need updating if OpenAI changes its launch documentation.

## Testing

Commands run to validate:

```sh
nixfmt --check agents/base-settings.nix
nix flake check --no-build --no-eval-cache
nix run .#sync-agents
# Run work Pi's model listing and verify openai/gpt-6-astra is present with no pattern warning.
```

## Summary

### What changed

- Added a custom `gpt-6-astra` definition to the work OpenAI provider, preserving the EU API endpoint and the built-in OpenAI catalog.
- Recorded text and image input, a 1.05M-token context window, 128K maximum output, launch pricing tiers, and supported reasoning levels from low through max.
- Kept `gpt-6-astra` enabled in the work profiles under the documented model ID; no `gpt-5.6-astra` alias was added because OpenAI does not document that model.

### What was tested

- `nixfmt --check`, `git diff --check`, `./scripts/check-structure.sh`, and `nix flake check --no-build --no-eval-cache` pass.
- `nix run .#sync-agents` synced the work and work-full base settings.
- The installed work wrapper's `pi --no-extensions --list-models astra` resolves `openai/gpt-6-astra` with a 1.05M context window, 128K output limit, reasoning, and image input; it emits no Astra pattern warning.

### Follow-up

- None.
