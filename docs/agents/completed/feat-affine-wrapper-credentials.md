# feat-affine-wrapper-credentials

> Load AFFiNE credentials through the existing Home Manager SOPS and Pi wrapper pattern.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

AFFiNE currently decrypts its token for every runner command when the environment token is absent.
The user requested the same mechanism as LiteLLM credentials rather than a separate cache.

## Plan

### Scope

Change `modules/home/programs/ai-agents.nix` only for runtime behavior.
Keep the existing runner fallback and mutation confirmation controls unchanged.

### Approach

1. Declare the existing encrypted AFFiNE token as a mode-0400 Home Manager SOPS secret when Pi is enabled.
2. Read that installed secret into `AFFINE_MCP_HTTP_TOKEN` only in the personal-browser Pi profile.
3. Validate source and configuration; activation requires a Nix switch and a new Pi process.

### Risks

The token is inherited by child processes, like existing provider credentials.
Secret plaintext must not enter generated configuration or the Nix store.
Agent asset sync alone does not activate Home Manager secrets or replace the installed wrapper.

## Testing

Passed `nixfmt --check modules/home/programs/ai-agents.nix`, `./scripts/check-structure.sh`, and `nix flake check --no-build`.
A dummy-token shell test verified personal-browser loading, other-profile exclusion, and missing-secret handling.
Passed `nix run .#sync-agents` and `nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link`.

## Summary

Implemented the existing SOPS installed-secret pattern, without a custom cache or per-command decryption on the normal wrapper path.
The runner fallback and write confirmation remain unchanged.
Build and source validation passed; live secret activation was not performed.
Run the Darwin switch wrapper and restart Pi to activate the secret and wrapper.
The trip upload remains blocked until activation or restored authentication.
