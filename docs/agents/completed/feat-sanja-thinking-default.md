# feat-sanja-thinking-default

> Enable medium-level thinking and visible reasoning for Sanja.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Sanja should use model thinking and show reasoning by default without the latency and cost of high thinking.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/openclaw-assistant.nix`

### Approach

1. Add shared, per-assistant OpenClaw thinking/reasoning options with safe defaults.
2. Set only Sanja to `thinkingDefault = "medium"` and `reasoningDefault = "on"`.
3. Deploy, restart Sanja, and verify the managed OpenClaw config.

### Risks

- Providers that do not support the requested thinking level may ignore it or use their own compatible level.

## Testing

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix hosts/nixos/ry4a/openclaw-assistant.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/cbm1y9drdbzpkrp62i8rhdpxvw6ln69c-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Sanja has medium thinking and visible reasoning by default.

### What was tested

- Nix formatting, diff checks, and evaluation passed.
- `deploy --skip-checks .#nixos-ry4a` succeeded and Sanja was restarted.
- Sanja's managed configuration reports `thinkingDefault = "medium"` and `reasoningDefault = "on"`.

### Follow-up

- None.
