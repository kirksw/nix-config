# feat-sanja-fallbacks-and-ssh-keys

> Adjust Sanja's failover order and persist assistant SSH host keys.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Sanja should prefer GPT-5.6 Luna, then MiniMax M3 and ZAI GLM 5.2, with GPT-5.4 as the final fallback. Assistant SSH host keys must survive MicroVM image recreation.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`

### Approach

1. Remove GLM 4.6V from Sanja's fallback chain and move GPT-5.4 last.
2. Store ED25519 and RSA SSH host keys under the persistent `/srv/assistant` volume.
3. Deploy, restart Sanja, and verify model order plus stable host-key files.

### Risks

- Sanja's SSH host key will change once more as the persistent key is first created. It remains stable after that.

## Testing

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/10gd1xza0bjv8k3lpgc10srjyhsryk6i-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Sanja now falls back from GPT-5.6 Luna to MiniMax M3, ZAI GLM 5.2, then GPT-5.4.
- All assistant MicroVMs persist ED25519 and RSA SSH host keys in their `/srv/assistant` volumes.

### What was tested

- Nix formatting, diff checks, and evaluation passed.
- `deploy --skip-checks .#nixos-ry4a` succeeded and Sanja was restarted.
- Sanja's managed OpenClaw config has the expected fallback order and `thinkingDefault = reasoningDefault = "off"`.
- Sanja generated persistent SSH keys, including ED25519 fingerprint `SHA256:Ni8wF+RIcZzHuNcxspkunrc0EQBzo7wpLXenFZNAeUc`.

### Follow-up

- None.
