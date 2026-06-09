# feat-pi-pr-reviewer-fixes

> Fix PR reviewer summary/reviewer subprocess failures on larger diffs.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The Pi PR reviewer extension spawns nested `pi --mode json -p` processes for summarization, review, and triage. The previous runner passed the full task (including PR diff) as a command-line argument. Larger PR diffs can exceed OS argv limits, causing summary output to disappear and reviewer subprocesses to fail.

## Plan

### Scope

- `agents/targets/pi/extensions/pr-reviewer/runner.ts`
- `agents/targets/pi/extensions/pr-reviewer/index.ts`

### Approach

1. Write nested Pi tasks to temporary files and pass them with Pi's `@file` message syntax instead of argv payloads.
2. Improve subprocess result handling so non-zero exits and empty/invalid JSON are surfaced clearly.
3. Add lightweight validation for JSON extraction and large task invocation.

### Risks

- `@file` behavior must be compatible with absolute temporary paths.
- Disabling too much nested Pi context could break custom-provider models, so provider/extension loading behavior was left unchanged for this fix.

## Testing

Commands run to validate:

```sh
PI_OFFLINE=1 pi --no-extensions -e ./agents/targets/pi/extensions/pr-reviewer/index.ts --mode json -p --no-tools --no-session 'say ok'
PI_OFFLINE=1 pi --no-extensions -e /tmp/test-pr-runner.ts --mode json -p --no-tools --no-session '/test-pr-runner-large'
PI_OFFLINE=1 pi --no-extensions -e /tmp/test-pr-runner-valid.ts --mode json -p --no-tools --no-session '/test-pr-runner-valid'
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents # expected failure: app does not exist in this flake
```

## Summary

### What changed

- The nested Pi runner now writes both system prompt and task prompt to a temporary directory and invokes the task via `@file`, avoiding argv-size failures on larger PR diffs.
- The runner now captures spawn errors in stderr, joins multiple assistant text parts, recursively cleans temporary files, and disables unrelated context files/skills/templates in nested reviewer runs.
- Summary/reviewer error reporting now includes stderr/exit context instead of silently falling back to `(no summary available)` or generic parse failures.
- The active generated Pi profile copy was manually refreshed for immediate local use.

### What was tested

- Extension load smoke test passed (Pi wrapper emitted pre-existing profile-copy warnings, but the extension loaded successfully).
- Large 300 KiB task smoke test reached Pi and failed only on the intentionally invalid model, confirming argv-size handling no longer blocks spawn.
- Valid nested `runPi` JSON extraction test passed.
- Repository structure check passed.
- `nix flake check --no-build` passed.

### Follow-up

- Existing backlog already tracks the missing `sync-agents` app referenced by the agent workflow.
