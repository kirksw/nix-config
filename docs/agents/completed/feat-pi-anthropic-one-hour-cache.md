# feat-pi-anthropic-one-hour-cache

> Set existing Anthropic prompt-cache breakpoints to a one-hour TTL in Pi provider requests.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi emits Anthropic cache breakpoints with the default five-minute lifetime.
Long-running agent workflows can exceed that window and pay for avoidable cache rewrites.
Anthropic supports `ttl: "1h"` on ephemeral cache controls, with one-hour cache writes billed at twice the base input-token price.

## Plan

### Scope

- `agents/targets/pi/extensions/anthropic-long-cache/index.ts`
- `agents/targets/pi/extensions/anthropic-long-cache/index.test.mjs`
- `docs/agents/feat-pi-anthropic-one-hour-cache.md`

### Approach

1. Add an auto-discovered Pi extension under `agents/targets/pi/extensions/`.
2. Intercept `before_provider_request` only for the direct `anthropic` provider using the `anthropic-messages` API.
3. Traverse the serialized provider payload and set every ephemeral `cache_control` object to `ttl: "1h"`.
4. Add focused tests for nested payloads and provider/API filtering.
5. Run the extension test, Pi load smoke test, repository structure check, flake evaluation, and profile sync.

### Risks

- One-hour cache writes cost more than five-minute writes, so this extension favors cache continuity in long workflows over the lower initial write price.
- Cache hits still require an identical prompt prefix; extending the TTL does not prevent misses caused by tool, system, message, thinking, or effort changes.
- Provider aliases and non-Anthropic transports are intentionally excluded because their support for Anthropic's one-hour TTL cannot be assumed.

## Testing

Commands run to validate:

```sh
node --experimental-strip-types --test agents/targets/pi/extensions/anthropic-long-cache/index.test.mjs
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/anthropic-long-cache/index.ts --mode json -p --no-tools --no-session 'say ok'
./scripts/check-structure.sh
git diff --check
nix flake check --no-build
nix run path:.#sync-agents -- --dry-run
nix run path:.#sync-agents
```

An initial `nix flake check path:. --no-build` attempt failed because the noncanonical path-flake evaluation referenced an unrealized generated source derivation.
The documented `nix flake check --no-build` command passed.

## Summary

### What changed

- Added `agents/targets/pi/extensions/anthropic-long-cache/index.ts` to rewrite existing ephemeral cache controls to `ttl: "1h"` immediately before direct Anthropic Messages API requests.
- Restricted the rewrite to `provider: "anthropic"` and `api: "anthropic-messages"` so provider aliases and other transports remain unchanged.
- Added focused tests for nested cache controls, existing TTL replacement, non-ephemeral controls, and provider/API filtering.
- Synced the extension into all four generated Pi profiles.

### What was tested

- The two focused Node tests passed.
- The extension loaded in an offline Pi smoke test.
- Repository structure validation and canonical flake evaluation passed.
- Sync dry-run and live sync passed.
- Every generated Pi profile contains an extension file whose SHA-256 matches the repository source.

### Follow-up

- None.
