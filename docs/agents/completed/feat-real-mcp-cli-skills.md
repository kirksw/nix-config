# feat-real-mcp-cli-skills

> Replace MCP schema-discovery prompts with deterministic, bounded CLI helpers used through Context Mode.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The instruction-only skills caused Context Mode to index Linear's full tool catalog and the model passed JSON as a positional MCPorter argument.
The result was unnecessary context storage and invalid Linear calls.

## What changed

- Added `linear/scripts/linear.mjs` with fixed `me`, `issues`, `search`, and `get` commands.
  It resolves the authenticated user, passes structured MCP input through MCPorter's `--args` option, and emits compact issue JSON.
- Added `recruiting/scripts/recruiting.mjs` to report Teamtailor availability without probing a disabled integration.
- Added `platform-status/scripts/platform-status.mjs` with bounded operation catalogs and bounded JSON output for Grafana and Hubble calls.
- Updated all three skills to invoke their script through `ctx_execute`, rather than letting the model rediscover raw MCP schemas.
- Added a script-relative MCPorter configuration fallback because Context Mode does not inherit Pi's `MCPORTER_CONFIG` environment variable.

## Testing

Commands run successfully:

```sh
./scripts/check-structure.sh
git diff --check
git diff --cached --check
nix run .#sync-agents
nix flake check --no-build --option eval-cache false
```

The generated Linear CLI returned a compact, three-item summary of Kirk Sweeney's 16 open issues through `ctx_execute` without `MCPORTER_CONFIG` in the Context Mode environment.
The generated recruiting CLI correctly reported disabled Teamtailor.
Platform-status catalog behavior is ready but Grafana requires mcporter OAuth authentication before it can list operations.

## Follow-up

Restart Pi to load the updated skills.
Authenticate Grafana or Hubble with MCPorter before using platform-status calls.
