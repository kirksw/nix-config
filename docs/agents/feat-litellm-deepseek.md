# feat-litellm-deepseek

> Add DeepSeek to home Pi and both assistants, and remove configured Codex-provider usage from home Pi.

## Status

- [x] Plan
- [x] Implement
- [ ] Test
- [ ] Complete

## Context

The user approved home-only Pi changes, preserving work profiles and the separate Codex CLI and credentials.
Equivalent LiteLLM GPT models replace Codex tier entries; unavailable GPT-5.4 fallbacks are removed and tier E uses Luna.
Manual provider selection is not blocked.

## Plan

1. Add both DeepSeek aliases to personal Pi enabled models and the shared assistant LiteLLM catalog.
2. Map personal Pi tiers locally without changing other targets or work tiers.
3. Test generated profiles and model metadata, sync Pi, and validate assistant configuration.

## Evidence And Risks

The tailnet gateway model-info endpoint lists both requested aliases.
DeepSeek V4 Pro reports 1000000 input tokens, 393216 output tokens, reasoning support, and text-only input.
DeepSeek Flash has no limit or capability metadata; retain conservative Pi defaults of 128000 context and 16384 output rather than inventing larger limits.
Python urllib requests to the public gateway returned Cloudflare error 1010.
The actual Node-based Pi provider succeeds with the same runtime credentials and public endpoint; no endpoint or credential change is needed.
Assistant changes need remote deployment before they take effect.

## Testing

- All 16 LiteLLM provider tests passed, including both DeepSeek metadata cases.
- Live tailnet discovery through the actual Pi extension registered both aliases.
- Both assistant configurations evaluate with both DeepSeek models and matching metadata.
- Full flake evaluation passed with `--no-build --option eval-cache false`.
- Pi sync succeeded; all three installed home profiles contain both aliases and no Codex tier entries.
- Profile regression validates home-only model selection, the tier E replacement, and absence of configured Codex usage.
- Public discovery through the actual Node-based Pi extension succeeded and registered 31 models, including both DeepSeek aliases.
- The earlier Python urllib probes returned Cloudflare error 1010; those probe failures do not reproduce in Pi's actual runtime.
- No inference requests or remote deployment were performed.

## Summary

Repository changes and local Pi sync are implemented.
Work Pi, shared non-Pi presets, assistant primary models, and stored credentials remain unchanged.
Public gateway access is verified in Pi's actual runtime.
Assistant deployment remains pending; do not claim remote rollout completion until deployed.
