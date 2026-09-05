# feat-litellm-astra-reasoning

> Correct Astra reasoning discovery and thinking levels without changing the LiteLLM transport.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The staged discovery change recognizes all GPT-6 IDs and does not describe Astra's supported thinking levels.
The approved fix must recognize only plain `gpt-6-astra` and `openai/gpt-6-astra`, while explicit boolean `supports_reasoning` metadata remains authoritative.
Existing index content and unrelated changes must remain untouched.

## Plan

### Scope

- `agents/packages/pi-litellm-provider/index.ts`
- `agents/packages/pi-litellm-provider/index.test.mjs`
- This feature plan, moved to `docs/agents/completed/` after validation.

### Approach

1. Read complete installed Pi 0.84.1 extension, custom-provider, models, and package documentation, the linked provider example, and actual provider types and thinking-level behavior before editing.
2. Keep existing GPT-5, MiniMax, and GLM inference unchanged and add an exact, case-insensitive Astra predicate.
3. For reasoning-enabled Astra only, provide a typed model-level map with `low`, `medium`, `high`, and `xhigh` identity values and `off`, `minimal`, and `max` set to `null`.
4. Test metadata precedence, both Astra IDs, narrow matching, unchanged other models, and discovery registration.
5. Validate against installed Pi capability/clamping and Chat Completions serialization, run package and repository checks, and inspect the working-tree diff and index fingerprint.

### Risks

- Pi's `getSupportedThinkingLevels` returns only `off` when `reasoning` is false, so disabled Astra entries must not receive an always-thinking map.
- Chat Completions sends mapped values as `reasoning_effort`; Astra's Responses-only `max` must not be advertised.
- No transport, credentials, generated assets, activation, deployment, or unrelated staged files may change.

### Definition of Done

- Both exact Astra IDs infer reasoning when metadata is absent or null.
- Explicit true/false metadata wins for Astra and other models.
- Reasoning-enabled Astra exposes exactly low/medium/high/xhigh through Pi and never sends max through the simple Chat Completions path.
- Other model outputs remain unchanged from the pre-GPT-6 behavior.
- Relevant tests pass, validation results are recorded, and the index is unchanged.

## Testing

Baseline: `npm test --prefix agents/packages/pi-litellm-provider` passed all 4 existing tests.
Installed read-only documentation root: `/nix/store/nqp3andrb4f053wiq53vpdg4anp18yn1-pi-0.84.1/lib/node_modules/@earendil-works/pi-coding-agent`.
Actual behavior inspected in `pi-ai/dist/models.js`, `pi-ai/dist/api/openai-completions.js`, and `dist/core/extensions/types.d.ts`.

### Results

- `npm test --prefix agents/packages/pi-litellm-provider`: all 10 tests passed.
- A `node --experimental-strip-types --input-type=module` smoke check imported the installed Pi 0.84.1 `models.js` and `api/openai-completions.js` modules directly.
  It exercised both Astra IDs with absent, null, true, and false metadata across all seven requested levels using a mocked `fetch` and SSE responses.
  All 56 requests passed capability, clamping, `/v1/chat/completions` URL, and serialized `reasoning_effort` assertions without network access.
  Enabled Astra exposed exactly low/medium/high/xhigh, off and minimal clamped to low, max clamped to xhigh, and disabled Astra exposed only off with no reasoning effort.
- `./scripts/check-structure.sh`: passed.
- `git diff --check`: passed.
- `git diff --cached | shasum -a 256`: unchanged from baseline, `9cb5e4ca4a30d00317b44f282fab4ea89477051850ea2ba021eb7bfee71de422`.
- `nix flake check --no-build`: failed because `w41x1bp1jz9bjdgvvsl258n6bqjjniiq-nix-config-agents-src.drv` is not valid.
- `nix flake check --no-build --option eval-cache false`: failed with the same invalid derivation path.
- `nix flake check "path:$PWD" --no-build --option eval-cache false`: timed out after 120 seconds; not a passing check or a verified workaround.

Full-flake logs are `/tmp/pi-litellm-astra-flake-check.log`, `/tmp/pi-litellm-astra-flake-check-no-cache.log`, and `/tmp/pi-litellm-astra-flake-check-path.log`.
The initial read-only subagent review found no verified recovery from those failed attempts alone.
No speculative operational or Nix changes were made.

### Read-only diagnosis and accepted validation

The user authorized read-only diagnosis and non-deploying validation, with long-running commands in the `astra-nix-validation` Herdr pane.
The repository and index were preserved throughout diagnosis.

```sh
nix eval .#checks.aarch64-darwin.agentic-factory-profiles.drvPath --raw --option eval-cache false --show-trace
nix flake check --no-build --option eval-cache false --show-trace
```

Both commands passed.
The targeted evaluation built the exact formerly invalid `w41x1bp1jz9bjdgvvsl258n6bqjjniiq-nix-config-agents-src.drv` and returned `/nix/store/l6zh471q8dkvw8mjcv3dl0pph62gmaza-agentic-factory-profiles.drv`.
The subsequent full check passed with the Astra source unchanged.
Logs are `/tmp/pi-astra-targeted-eval.log` and `/tmp/pi-astra-flake-after-targeted.log`.

An isolated staged-only baseline was exported from all 665 index blobs into `/tmp/personal/pi-astra-staged-baseline-w7e5tied` without modifying the index or working tree.
Its full check also passed:

```sh
nix flake check path:/tmp/personal/pi-astra-staged-baseline-w7e5tied --no-build --option eval-cache false --show-trace
```

The baseline log is `/tmp/pi-astra-staged-baseline-check.log`.
This excludes a deterministic Astra source regression as the validation blocker; the precise cause of the original invalid-derivation state remains unproven.

`flake/apps.nix:163` defines the copied agent-source derivation and passes it to `mkProfileMeta` at line 234.
The pinned nix-agents generators read `src/AGENTS.md` during evaluation, creating an import-from-derivation dependency.
Consequently, these non-activating validation commands can build agent-source inputs even when full check builds are disabled.

A final default `nix flake check --no-build` still failed with cached failures for the Pi MLX and settings-merge checks and `evaluation of cached failed attribute 'apps.aarch64-darwin.sync-agents.isValidApp' unexpectedly succeeded`.
Its log is `/tmp/pi-astra-final-flake-check.log`.
No evaluation caches were deleted or changed manually.
The user explicitly accepted the successful full checks with `--option eval-cache false` and requested that caches remain untouched.
Full checks cover the current compatible system; Nix explicitly omitted `aarch64-linux`, `x86_64-darwin`, and `x86_64-linux`.

A second read-only subagent verified the recovery evidence and confirmed that a runbook note could document the targeted-evaluation then cache-bypassed full-check sequence as an observed recovery, not a universal fix.
That optional troubleshooting documentation was recommended to the user; no unrelated runbook changes were made.
Package tests, structure checks, diff checks, and the unchanged staged fingerprint were rechecked successfully.

## Summary

### What changed

- Restricted GPT-6 fallback reasoning inference to the two exact Astra aliases, retaining existing case-insensitive matching and other model inference.
- Added an Astra-only `thinkingLevelMap` typed through Pi's `ProviderModelConfig`, honoring explicit false metadata and retaining the existing transport.
- Added metadata, alias, negative-matching, unchanged-model, and both discovery-path regressions.

### Validation outcome

Implementation and accepted validation are complete and ready for parent review.
All 10 package tests, 56 mocked installed-Pi requests, structure and diff checks, and cache-bypassed full-flake checks passed.
The default cached check retains the documented environment caveat; the user explicitly accepted bypassing it without cache recovery.
No required implementation follow-up remains.
No generated files, index entries, unrelated files, or Nix-store files were manually edited.
No activation, deployment, commit, push, or merge was performed.

### Activation commands (not run)

After review, from the repository root:

```sh
nix run "path:$PWD#sync-agents" --option eval-cache false
```

Then restart the affected personal Pi profile, or use `/reload` in the existing Pi session after synchronization.
The sync app updates all configured agent assets, including other pending repository changes; review the complete change set before activation.
No transport or credential change requires a Darwin switch for this fix.
