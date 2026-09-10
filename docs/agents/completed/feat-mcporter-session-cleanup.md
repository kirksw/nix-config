# feat-mcporter-session-cleanup

> Terminate HTTP MCP sessions before closing generated home CLI clients.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

MCPorter 0.13.3 closes HTTP transports without sending session DELETE. Independent AFFiNE CLI calls accumulate server sessions; production currently rejects initialization with HTTP 503 at capacity. Published 0.13.10 also lacks termination in `RuntimeConnectionCache.closeContext` (inspected npm tarball). No server restart, deployment, or commits are authorized. Existing credential work and `.pi` are preserved.

Symptom that triggered this plan: `bash skills/affine/scripts/run.sh <command>` returned `SSE error: Non-200 status code (400)` after roughly 20 successful calls. A direct MCP `initialize` request returned the real cause: HTTP 503 with JSON-RPC `-32002`, `Server busy: maximum HTTP MCP session capacity reached`.

## Plan

### Scope

- `flake/apps.nix` home generator; isolated, locked tooling under `scripts/mcporter`.
- Source-runtime patch, local HTTP integration tests, offline schema regeneration helper.
- Regenerate `agents/defs/skills/affine/generated/affine.cjs` through generator APIs only.

### Approach

1. Stage exact npm dependencies using `npm ci` and a lockfile; apply a checked-in patch to the staged published runtime modules, never the npm cache or generated bundles.
2. Await bounded best-effort session termination before transport/client closure, including failed initialization; preserve HTTP server errors instead of legacy SSE fallback.
3. Honor an existing `AFFINE_MCP_HTTP_TOKEN` before decrypting SOPS.
4. Exercise more than 20 independent clients, tool errors, DELETE rejection/hangs, and primary HTTP503 against a local fixture; regenerate offline using embedded schemas when production is unavailable.
5. Run focused and repository checks; record exact outcomes and remaining limitations.

### Risks

- Server DELETE failure/timeout cannot guarantee remote reclamation; always close local resources and preserve the original operation result/error.
- Published JS modules are the npm package's unbundled runtime source; patch applicability and lockfile pinning guard upstream drift.
- Offline regeneration preserves existing schema knowledge rather than discovering production schema changes.

## Testing

Focused integration suite, run through the same staging path the generator uses:

```sh
cd scripts/mcporter && bash run.sh --script "$PWD/session-cleanup.test.mjs"
```

Result: 9 of 9 subcases pass, including `25 independent generated CLI processes never exhaust 20-session capacity` (asserts zero live sessions and 26 DELETEs), delete-failure, delete-timeout, bounded cleanup on tool and RPC errors, `HTTP503 remains primary error without SSE fallback`, idempotent `runtime.close`, and ordering proof that termination precedes both closes.

Repository and artifact checks:

```sh
nixfmt --check flake/apps.nix modules/home/programs/ai-agents.nix
nix flake check --no-build
nix run .#sync-agents
nix run .#update-home-mcp-skills -- affine
```

Results: formatting passes; `nix flake check --no-build` exits 0; `sync-agents` succeeds; the update app stages, patches, and reaches the server. The bundle regeneration itself succeeded offline (78 embedded tools), and the app run additionally confirmed the patched 5xx handling in production by reporting `Server busy: maximum HTTP MCP session capacity reached` as the primary error with no SSE fallback message. After capacity freed, 25 sequential production calls succeeded 25/25 in 6 s, and the server logged 26 sessions initialized and 26 closed.

## Summary

### What changed

- `scripts/mcporter/`: locked tooling (`package.json`, `package-lock.json`), `session-cleanup.patch`, `run.sh` staging runner, `session-cleanup.test.mjs`, `regenerate-offline.mjs`.
- `scripts/mcporter/session-cleanup.patch` adds `dist/runtime/terminate-http-session.js` and calls it from `RuntimeConnectionCache.closeContext` and from the failed-initialization path in `http-transport.js`; it also stops 5xx responses from falling back to legacy SSE.
- `flake/apps.nix`: generator now runs through `scripts/mcporter/run.sh`, and reuses an existing `AFFINE_MCP_HTTP_TOKEN` instead of always decrypting SOPS.
- `agents/defs/skills/affine/generated/affine.cjs`: regenerated through MCPorter's template and bundler APIs (never edited by hand) with the patched runtime inlined.

### What was tested

- 9/9 integration subcases against a local HTTP MCP fixture, including 25 sequential CLI processes against a 20-session cap.
- Bundle integrity before and after installation: 78 tools, runtime token placeholder preserved, no plaintext token.
- `nixfmt`, `nix flake check --no-build`, `sync-agents`, and a live update-app run.
- Post-sync profile copy verified to contain the patched runtime and no plaintext token.

### Follow-up

- Production reclamation was re-checked after the client fix landed. The server is `ghcr.io/dawncr0w/affine-mcp-server:3.6.0` (deployment `affine-mcp`, namespace `affine`, NodePort 31410) with `maxSessions=32` and a 30-minute idle timeout swept every 30 s. It **does** reclaim sessions: the batch created at 22:37–22:41 was closed at 23:08–23:11, and capacity returned at 23:24. The outage came from 40 sessions created inside one 30-minute window, with 32 outstanding at once. The earlier assumption that the server never reclaims sessions was wrong; the failure was capacity exhaustion driven by the client leak, not a stuck server.
- Acceptance test after the fix: 25 sequential independent production calls completed 25/25 in 6 s, with the server logging 26 sessions initialized and 26 closed — no accumulation.
- Optional hardening towards clients that never send DELETE: raise `AFFINE_MCP_HTTP_MAX_SESSIONS` or lower `AFFINE_MCP_HTTP_SESSION_IDLE_TIMEOUT_MS`. Tracked in `docs/BACKLOG.md`.
