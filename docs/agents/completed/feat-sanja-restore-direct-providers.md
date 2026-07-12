# feat-sanja-restore-direct-providers

> Restore Sanja's direct MiniMax and ZAI providers while retaining a restricted Codex catalog.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Sanja needs direct MiniMax and ZAI access as well as Codex OAuth. Only the Codex choices are restricted to GPT-5.4 and GPT-5.6 Luna; GPT-5.6 Luna is the default.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/openclaw-assistant.nix`

### Approach

1. Restore direct provider mode so runtime MiniMax/ZAI secrets and providers are available to Sanja.
2. Use GPT-5.6 Luna as primary, then GPT-5.4, MiniMax M3, and ZAI models as fallbacks.
3. Keep the allowlist to the two approved Codex models plus the restored direct models.

### Risks

- Sanja's OpenClaw SSH host key is generated in the ephemeral VM root filesystem, so it changes whenever a new system image is deployed.

## Testing

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix hosts/nixos/ry4a/openclaw-assistant.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/bj964ia65pk36q5p0xp2249bxj7raiz3-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Sanja now defaults to `openai/gpt-5.6-luna`.
- Her approved fallback chain is GPT-5.4, MiniMax M3, ZAI GLM 5.2, then ZAI GLM 4.6V.
- Runtime MiniMax and ZAI secrets were restored.

### What was tested

- Nix formatting, diff checks, and evaluation passed.
- `deploy --skip-checks .#nixos-ry4a` succeeded and Sanja was restarted.
- Sanja's generated Nix config has exactly the five approved model references, and only the expected runtime secrets are present.

### Follow-up

- None.
