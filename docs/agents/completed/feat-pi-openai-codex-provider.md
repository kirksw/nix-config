# feat-pi-openai-codex-provider

> Make Pi personal-profile OpenAI-backed agent tiers use the `openai-codex/` provider while leaving OpenCode on `openai/`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`chaos-demon` in the generated Pi `personal-default` profile resolved `balanced` to `openai/gpt-5.3-codex`. Pi's personal profile is authenticated through the `openai-codex` provider, so subagents that use OpenAI-backed tiers failed with `No API key found for openai`. OpenCode should continue using the existing `openai/` model strings.

## Plan

### Scope

Files affected:
- `agents/targets/pi/provider-overrides.nix` (new)
- `agents/default.nix`
- `modules/home/programs/ai-agents.nix`
- `flake/apps.nix`
- `docs/agents/completed/feat-pi-openai-codex-provider.md`

### Approach

1. Add a Pi-only module that overrides the `personal-default` profile's OpenAI-backed tiers to `openai-codex/...`.
2. Expose Pi-specific modules from `agents/default.nix`.
3. Use Pi-specific modules only when generating/syncing Pi assets in the home module and `sync-agents` app.
4. Leave shared/default modules unchanged so OpenCode still emits `openai/...`.
5. Validate generated Pi agents and flake structure.

### Risks

- If the Pi override is accidentally included in shared modules, OpenCode model strings would be changed incorrectly.
- Work profile mappings may need separate handling later if work Pi should also use `openai-codex`.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
rg -n '^model:' ~/.config/nix-agents/pi/bases/personal/profiles/personal-default/agents/chaos-demon.md
rg -n '^model:' ~/.config/nix-agents/opencode/bases/personal/profiles/personal-default/agents/chaos-demon.md
```

Also ran a `chaos-demon` subagent smoke test after syncing; it no longer fails with the missing `openai` API key error.

## Summary

### What changed

- Added `agents/targets/pi/provider-overrides.nix` with Pi-only `personal-default` tier overrides:
  - `fast = openai-codex/gpt-5.4-mini`
  - `balanced = openai-codex/gpt-5.3-codex`
- Exposed `piModules` from `agents/default.nix`.
- Updated the Pi wrapper generation in `modules/home/programs/ai-agents.nix` to use `piModules`.
- Updated `flake/apps.nix` so `sync-agents` uses `piModules` only for the Pi target.
- Confirmed OpenCode still generates `openai/gpt-5.3-codex` for `chaos-demon`.

### What was tested

- Repository structure validation.
- Flake evaluation.
- Dry-run agent sync generation.
- Actual `sync-agents` local sync.
- Generated model frontmatter for Pi and OpenCode.
- `chaos-demon` subagent smoke test.

### Follow-up

- None.
