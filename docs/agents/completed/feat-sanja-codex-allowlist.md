# feat-sanja-codex-allowlist

> Restrict Sanja to the two approved Codex OAuth models.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Sanja must use only GPT-5.4 and GPT-5.6 Luna. MiniMax and ZAI must no longer be configured for or exposed to her.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/openclaw-assistant.nix`

### Approach

1. Use the native `openai/*` Codex OAuth route for Sanja.
2. Set GPT-5.4 as primary, GPT-5.6 Luna as fallback, and configure those two models as the complete OpenClaw allowlist.
3. Skip direct-provider setup, which also removes MiniMax/ZAI secret mounts from Sanja.
4. Deploy and restart Sanja, then verify the model catalog.

### Risks

- The Codex account must expose both models; a missing model will fail rather than falling back to an unapproved model.

## Testing

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix hosts/nixos/ry4a/openclaw-assistant.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/xbpc0xm5946sifv1q7rxxgqbcbvzg8zf-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Sanja now uses native Codex OAuth with `openai/gpt-5.4` primary and `openai/gpt-5.6-luna` fallback.
- `agents.defaults.models` is a two-model allowlist; MiniMax and ZAI are neither configured nor mounted for Sanja.

### What was tested

- Nix formatting, diff checks, and Nix evaluation passed.
- `deploy --skip-checks .#nixos-ry4a` succeeded and Sanja was restarted.
- `/etc/openclaw/openclaw.json` inside Sanja has exactly the two configured model keys, and `openclaw models status` resolves the expected primary/fallback pair.

### Follow-up

- None.
