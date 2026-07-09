# feat-direct-assistant-providers

> Route Kirk and Sanja directly to MiniMax and ZAI instead of the home LLM router.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Kirk and Sanja need direct MiniMax and ZAI provider access. OpenAI Codex will be authenticated interactively inside each persistent assistant VM.

## Plan

### Scope

- `hosts/nixos/ry4a/agent-microvms.nix`
- `hosts/nixos/ry4a/openclaw-assistant.nix`

### Approach

1. Give only Kirk and Sanja direct provider configuration and direct-model fallbacks.
2. Mount the existing encrypted MiniMax and ZAI SOPS secrets into those VMs at runtime.
3. Keep Codex OAuth state in the persistent `agent` home; no OpenAI API key is generated or stored.
4. Deploy, restart the two MicroVMs, then authenticate Codex as `agent`.

### Risks

- Direct provider credentials are visible to the OpenClaw gateway process; they must remain runtime SOPS files.
- The old router API keys should be rotated/revoked after the migration is verified.

## Testing

Commands run:

```sh
nixfmt hosts/nixos/ry4a/agent-microvms.nix hosts/nixos/ry4a/openclaw-assistant.nix
git diff --check
nix eval --raw .#nixosConfigurations.nixos-ry4a.config.system.build.toplevel.drvPath
```

Result: evaluation succeeded with `/nix/store/xhyk62rzqkil2nv2wypc35jay4yq1k7a-nixos-system-nixos-ry4a-26.11.20260705.6edbf1a.drv`.

## Summary

### What changed

- Kirk and Sanja now default to direct `minimax/MiniMax-M3`, with direct ZAI fallbacks.
- Existing encrypted MiniMax/ZAI secrets are mounted only for those two assistants at runtime.
- Their LLM-router credentials are no longer installed; no OpenAI API key was added.

### What was tested

- Nix evaluation and formatting checks completed successfully.
- `deploy --skip-checks .#nixos-ry4a` activated the configuration.
- Both `microvm@kirk-assistant` and `microvm@sanja-assistant` were restarted and are active.
- The host has only their runtime MiniMax/ZAI secrets; their old `llm_router_api_key` files are absent.

### Follow-up

- User action: authenticate OpenAI Codex with `openclaw models auth login --provider openai --device-code` as `agent` inside each persistent assistant VM. OpenClaw keeps the OAuth profile in its persistent auth store under `/var/lib/openclaw`.
- Rotate/revoke the removed LLM-router API keys after direct-provider use is confirmed.
