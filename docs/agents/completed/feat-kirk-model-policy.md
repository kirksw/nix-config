# feat-kirk-model-policy

> Configure Kirk's unrestricted model catalog and main-agent defaults.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Kirk's main OpenClaw agent should use GPT-5.6 Luna, then MiniMax M3 and ZAI GLM 5.2. Future subagents need access to GPT-5.6 Terra and GPT-5.6 Sol.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`

### Approach

1. Leave Kirk without `modelAllowlist`, which preserves the full OpenClaw provider catalog.
2. Set Luna as main-agent primary and MiniMax M3/GLM 5.2 as ordered fallbacks.
3. Enable medium thinking and visible reasoning.
4. Deploy, restart Kirk, and verify the managed config.

### Risks

- Kirk must authenticate the native OpenAI/Codex provider before GPT-5.6 models can serve requests.

## Testing

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/bzrndsch5q309azyc6d06avxp72kally-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Kirk now defaults to `openai/gpt-5.6-luna`, then MiniMax M3 and ZAI GLM 5.2.
- Kirk has medium thinking and visible reasoning enabled.
- No `models` allowlist is generated, leaving the full provider catalog available for future Terra/Sol subagents.

### What was tested

- Nix formatting, diff checks, and evaluation passed.
- deploy-rs remote build failed without a useful builder error; direct remote `nixos-rebuild switch --flake .#nixos-ry4a` succeeded from a clean source copy.
- Kirk was restarted; its managed config and runtime MiniMax/ZAI secrets match the requested policy.
- Kirk's persisted OpenAI OAuth profile is present.

### Follow-up

- Diagnose the deploy-rs remote-build failure.
