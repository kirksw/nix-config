# feat-model-tier-fallbacks

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Replace legacy single-model tiers with S/A/B/C/D/E model chains. Work uses OpenAI and Anthropic; home uses OpenAI Codex, Z.AI, and MiniMax.

## Changes

- Added ordered tier-chain support to `nix-agents` PR #91 and merged it as `3da8a54`.
- Pi agents receive `fallbackModels` for provider/model failures.
- Migrated all managed agent roles to S/A/B/C/D tiers; E is available for utility agents.
- Applied the agreed provider-specific S–E chains to standard and factory profiles.

## Validation

```sh
# nix-agents
nix flake check

# nix-config
nixfmt agents/presets/profiles.nix agents/presets/factory.nix agents/targets/pi/provider-overrides.nix agents/defs/agents/*.nix
git diff --check
nix flake check --no-build
```

Result: both flake checks passed. The attempted `nix eval .#agentic-factory-profiles.drvPath` used an invalid output path; the dedicated `checks.aarch64-darwin.agentic-factory-profiles` check passed.

## Summary

- Synced all managed agent profiles with `nix run .#sync-agents`.
- Verified generated Pi agent frontmatter resolves S/B primaries and emits ordered `fallbackModels` where configured.
- Restart Pi sessions to load the synced agent definitions.
