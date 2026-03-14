# feat-codex-swe-pruner-mcp-fix

> Fix the Codex swe-pruner MCP config shape so the client reads the server env correctly.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Codex was starting the `swe-pruner` MCP server from the Home Manager-generated profile, but the
generated TOML used `environment = { ... }`. Current Codex expects `env = { ... }`, so the env was
silently dropped during parsing and the repo docs still showed the stale key.

## Plan

### Scope

- `modules/home/programs/codex.nix` -- fix the generated Codex MCP stanza.
- `agents/codex/config.toml` -- remove a stale Codex feature flag from the repo-managed config.
- `docs/swe-pruner-mcp-setup.md` -- align the Codex setup instructions with the live config shape.

### Approach

1. Confirm the current Codex parser behavior with `codex mcp get` and config overrides.
2. Update the generated Nix config and manual Codex snippet to use `env`.
3. Remove stale Codex config that no longer matches the installed CLI feature set.

### Risks

- This fixes the confirmed config-schema mismatch, but it does not upgrade the upstream
  `swe-pruner-mcp` package. Any separate server/client protocol incompatibility would need a
  package update.

## Testing

Commands run to validate:

```sh
codex mcp list --json
codex mcp get swe-pruner
codex -c 'mcp_servers.swe-pruner.env={MODEL_PATH="/tmp/model",STATS_FILE="/tmp/stats.json"}' mcp get swe-pruner
nix flake check --no-build
nix run .#sync-agents
apps/aarch64-darwin/build lunar
```

## Summary

### What changed

- Switched the generated Codex swe-pruner stanza from `environment` to `env`.
- Removed the stale `experimental_use_rmcp_client` flag from the repo Codex config.
- Updated the Codex setup doc to reflect the profile-based Home Manager config and current CLI
  syntax.

### What was tested

- Verified the current parsed server shape with `codex mcp list --json`.
- Verified the existing server entry with `codex mcp get swe-pruner`.
- Verified that `env` is the key Codex currently recognizes by overriding it on the command line.
- Ran `nix flake check --no-build`.
- Ran `nix run .#sync-agents`.
- Ran `apps/aarch64-darwin/build lunar`.

### Follow-up

- None.
