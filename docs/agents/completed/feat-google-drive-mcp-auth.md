# feat-google-drive-mcp-auth

> Authenticate the work-profile Google Drive MCP through existing gcloud user credentials.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Google Drive MCP does not support dynamic client registration, so Pi's default OAuth flow cannot authenticate it with only the user's existing token. The work profile now wraps the remote endpoint with a local stdio MCP bridge that obtains a short-lived token from `gcloud auth print-access-token` for each request.

## What changed

- Added `agents/packages/google-drive-mcp-auth/`, a local stdio-to-HTTP MCP bridge.
- The bridge forwards bearer authentication, MCP session IDs, and negotiated protocol versions.
- Added bounded response handling, SSE parsing, redirect protection, session recovery, and token-safe diagnostics.
- Registered the bridge as the work-profile `google-drive` MCP server.
- Enabled gcloud for the Darwin work host.
- Added focused bridge tests.

## Validation

- 11 Python unit tests passed.
- Python compilation passed.
- Nix formatting and diff checks passed.
- `nix build .#google-drive-mcp-auth --no-link` passed.
- `nix run .#sync-agents` completed successfully.

## Limitations

- gcloud must be authenticated with Google Drive MCP/API scopes.
- The bridge handles one complete SSE response per request; it is not a long-lived event-stream relay.
- The bridge serializes requests through stdin.
- Full repository flake checks still encounter unrelated existing generated-source/store-path failures.
