# feat-litellm-context-window

> Preserve explicit LiteLLM total-context metadata when registering Pi models.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi displayed 144k for Astra because the extension mapped `max_input_tokens` to `contextWindow`.
Removing the input limit caused the extension to use its 128k fallback instead of the explicit 272k context budget.

### References

- Gateway source: [cntd-io/k8s-config LiteLLM configuration](https://github.com/cntd-io/k8s-config/blob/0386857e00798631d7cfe41754fd76e05e18c0c6/clusters/k3s/flux-system/litellm/litellm.yaml).
  The `openai/gpt-6-astra` entry declares `context_window: 272000` and `max_output_tokens: 128000` separately.
- A read-only request to the documented tailnet `/v1/model/info` endpoint during diagnosis returned `context_window: 272000`, `max_input_tokens: 144000`, and `max_output_tokens: 128000` before the user removed the input limit.
  The 1M variant returned `context_window: 1050000`, `max_input_tokens: 922000`, and `max_output_tokens: 128000`.
- Installed Pi 0.84.1 `docs/models.md`, Model Configuration: `contextWindow` is the context size; `maxTokens` is the maximum output size.
  Installed `dist/core/agent-session.js`, `getContextUsage()`, divides estimated context tokens by `model.contextWindow`.
  Installed `dist/modes/interactive/components/footer.js` displays that context window without subtracting output capacity.
- The local Pi model catalog registers `openai-codex/gpt-6-astra` with `contextWindow: 272000` and `maxTokens: 128000`.

## Plan

### Scope

Only the LiteLLM extension metadata mapping, package tests, and this evidence record change.
Authentication, endpoints, model reasoning, gateway configuration, and generated profiles are outside the implementation scope.

### Approach

1. Accept optional nullable `context_window` metadata.
2. Prefer a positive integer `context_window`, then valid `max_input_tokens`, then the existing 128000 default.
3. Keep output limits independent and unchanged.
4. Reproduce the failure in tests before the implementation, then validate mapping and discovery registration.

### Risks

An explicit total context budget does not prove that a gateway accepts every input/output combination below that budget.
This change consumes declared metadata; it does not override server enforcement or infer context by adding input and output limits.
Existing credentials and discovery fallback behavior remain unchanged.

### Definition Of Done

- Explicit total context wins over input metadata, including when input metadata is absent.
- Missing or invalid total context retains valid legacy input limits or the existing default.
- Tests cover standard and 1M contexts, invalid metadata, output independence, and discovery-to-registration behavior.
- Relevant validation and the final diff are reviewed.

## Testing

- `npm --prefix agents/packages/pi-litellm-provider test`: regression-first run failed 6 of 15 tests on the original implementation, including 128000 versus 272000 with no input limit.
- The same command after the fix passed all 15 tests.
- `./scripts/check-structure.sh`: passed.
- `git diff --check`: passed; implementation and test diff reviewed.
- `nix flake check --no-build`: blocked by invalid derivation `3l4hdalvbqy5m891dpr3a8i3g9146w3v-nix-config-agents-src.drv` in shared agent outputs.
- Retrying with `--option eval-cache false` failed with the same invalid derivation.
- A subsequent targeted `nix eval .#apps.aarch64-darwin.sync-agents.program --raw --show-trace` succeeded and built the current agent-source derivation.
  The original invalid-derivation failure no longer reproduces; its precise cause was not established.
- A fresh `nix flake check --no-build` passed, with expected dirty-tree and incompatible-system warnings and upstream option-deprecation warnings.
- `nix run .#sync-agents -- --dry-run` passed, then `nix run .#sync-agents` completed successfully.
- Verified the personal profile package path resolves to a Nix-store copy containing the corrected context-window mapping.
  This was a full agent sync, including existing user configuration changes.
- `apply_patch` was unavailable; the supported edit tool successfully applied the implementation instead.
  A read-only agent confirmed existing instructions already permit this fallback, so no additional editing guardrail is needed.
- A read-only agent checked both Nix failure logs and rejected documenting cache disabling as a recovery: the retry did not fix this failure.
  A verified Nix recovery is still needed before recommending a runbook change.

## Summary

The source fix and regression tests are complete.
The mapping prefers explicit total context while preserving legacy defaults and independent output limits.
Repository-wide Nix validation and declarative agent sync now pass.
Generated assets were updated only through the sync app; no gateway configuration was changed.
Restart Pi to load the synced extension.
The sync tool warns that pre-syncMode wrappers can restore their embedded generation on launch until the next Darwin switch.
