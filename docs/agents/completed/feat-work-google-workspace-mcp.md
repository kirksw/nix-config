# feat-work-google-workspace-mcp

> Add Google Workspace MCP through MCPorter to the shared Pi work profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi work agents need access to the Google Workspace MCP endpoint at `https://google-workspace-mcp.prod.lunar.tech/`.
The work-browser profile intentionally has no work MCP servers and remains unchanged.

## Plan

### Scope

- Add one server to `piWorkMcpServers` in `agents/base-settings.nix`.
- This covers `work`, `work-default`, and `work-web` through their existing shared MCPorter config.
- Do not change personal profiles or `work-browser`.

### Approach

1. Add the endpoint using the existing remote OAuth MCP server format.
2. Validate generated work MCPorter settings and profile isolation.
3. Record validation in this completed plan.

### Risks

- The endpoint requires OAuth credentials to use its tools.
- Live MCP tool discovery was not tested without authentication.

## Testing

The following checks passed:

```sh
nixfmt --check agents/base-settings.nix
statix check agents/base-settings.nix
nix run nixpkgs#deadnix -- --fail agents/base-settings.nix
./scripts/check-structure.sh
git diff --check
nix flake check --no-build
nix build .#checks.aarch64-darwin.pi-experimental-profiles --no-link
nix run .#sync-agents
```

A focused JSON assertion confirmed that the synced `google-workspace` server uses the requested URL, OAuth, and ephemeral lifecycle in `work`, `work-default`, and `work-web`.
The server is absent from `work-browser` and all personal bases.
An unauthenticated request to the endpoint returned HTTP 401 with Bearer OAuth resource metadata, consistent with requiring OAuth login.

## Summary

### What changed

- Added `google-workspace` to the shared work MCPorter server definitions.
- Preserved the work-browser and personal MCP isolation.

### What was tested

- Nix checks, Pi profile build, agent sync, and the generated MCPorter JSON assertions passed.

### Follow-up

- Authenticate with MCPPorter in a work session before using Google Workspace tools.
