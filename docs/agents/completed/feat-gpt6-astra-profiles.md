# feat-gpt6-astra-profiles

> Add the new OpenAI flagship `gpt-6-astra` to personal and work Pi profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

OpenAI released GPT-6 Astra on 2026-09-03. It is the new flagship above GPT-5.6 Sol (roughly 2x Sol pricing, stronger cyber and vision capabilities). The personal and work profiles currently top out at tier S with `gpt-5.6-sol`, so Astra should become the new tier S lead model, keeping Sol as the ordered fallback. Default models stay unchanged (`glm-5.2` personal, `gpt-5.6-terra` work) because Astra's per-token cost is 2-5x higher and no default change was requested.

## Plan

### Scope

- `agents/presets/profiles.nix`: tier S lists in `personal-default`, `personal-full`, `work-default`, `work-full`.
- `agents/base-settings.nix`: `piPersonalModelDefaults.enabledModels` and `piWorkModelDefaults.enabledModels`.

### Approach

1. Prepend `openai-codex/gpt-6-astra` to tier S in both personal profiles (Codex OAuth route, matching the existing Sol entry).
2. Prepend `openai/gpt-6-astra` to tier S in both work profiles (work OpenAI key route).
3. Add `litellm/openai/gpt-6-astra` to personal Pi `enabledModels` and `gpt-6-astra` to work Pi `enabledModels`.
4. Leave `defaultModel`, `defaultProvider`, and lower tiers untouched.

### Risks

- The Codex subscription or the personal LiteLLM gateway may not expose `gpt-6-astra` yet on launch day; the tier chain falls back to `gpt-5.6-sol`, and an unresolvable `enabledModels` entry is inert in the Pi model picker.
- Cost: any session or subagent that explicitly picks tier S lead now pays Astra pricing.
- Generated tier manifests under `~/.config/nix-agents` need a `sync-agents` run to reflect the new chains.

## Testing

Commands run to validate:

```sh
nixfmt agents/presets/profiles.nix agents/base-settings.nix
git diff --check
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

Result: all commands passed. `nix flake check --no-build` initially reported stale eval-cache failures (`agents-src.drv` not valid under `--no-build`); building the derivation and re-running with `--no-eval-cache` passed cleanly. Generated profile roots under `~/.config/nix-agents/pi/bases/{personal,personal-full,work,work-full}` were re-synced and verified to contain `gpt-6-astra` in tier S and `enabledModels`.

## Summary

### What changed

- Prepended `openai-codex/gpt-6-astra` to tier S in `personal-default` and `personal-full`, and `openai/gpt-6-astra` to tier S in `work-default` and `work-full` (`agents/presets/profiles.nix`); `gpt-5.6-sol` remains the ordered fallback.
- Added `litellm/openai/gpt-6-astra` to personal Pi `enabledModels` and `gpt-6-astra` to work Pi `enabledModels` (`agents/base-settings.nix`).
- Default models and lower tiers are unchanged.

### What was tested

- `nixfmt --check`, `git diff --check`, `./scripts/check-structure.sh`, `nix flake check --no-build` all pass.
- `nix run .#sync-agents` re-synced all bases; verified `gpt-6-astra` present in all four generated tier manifests and settings files.

### Follow-up

- None. If the Codex subscription or LiteLLM gateway lacks `gpt-6-astra` availability, tier S silently falls back to `gpt-5.6-sol`; no action needed.
