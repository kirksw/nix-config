# feat-pi-landing-workflow

> Add a project-local Pi extension that opens a full-screen landing workflow panel on `/land`.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Pi already has project-owned extensions in `agents/targets/pi/extensions/`. This feature adds a focused landing workflow panel that can be invoked with `/land` and visually walks through a standard landing sequence with progress, timing, and per-step status.

## Plan

### Scope

Files affected:
- `agents/targets/pi/extensions/landing-workflow/index.ts` (new)
- `docs/agents/completed/feat-pi-landing-workflow.md` (new)

### Approach

1. Add a new Pi extension under `agents/targets/pi/extensions/landing-workflow/` so it is picked up by the existing Pi target auto-discovery.
2. Register a `/land` command that opens a full-screen custom TUI component.
3. Implement a timed multi-step workflow covering:
   - fetch/rebase
   - tests
   - share Pi session link
   - commit/rebase
   - tests again
   - push again
4. Render a dashboard-style panel showing header, status, elapsed time, overall progress, current step, and step list.
5. Support per-step durations, timed transitions, restart/cancel behavior, and a final success state.
6. Validate the extension loads and the repo structure/checks still pass.

### Risks

- The workflow is intentionally simulated/timed rather than executing real git or test commands.
- TUI rendering must stay within terminal width limits and handle repeated redraws cleanly.
- The extension should remain interactive-only and fail gracefully in print/non-interactive modes.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
apps/aarch64-darwin/build lunar
pi --offline --no-session -e ./agents/targets/pi/extensions/landing-workflow/index.ts -p "/land"
```

## Summary

### What changed

- Added `agents/targets/pi/extensions/landing-workflow/index.ts`.
- Registered a new `/land` command for Pi.
- Implemented a full-screen custom TUI landing workflow panel.
- Added timed step transitions, elapsed time, overall progress bar, current-step display, per-step duration rendering, cancel/restart controls, and final success state.
- Added support for `/land fast` and `/land slow` timing presets.

### What was tested

- Repository structure validation via `./scripts/check-structure.sh`.
- Flake evaluation via `nix flake check --no-build`.
- Darwin config build via `apps/aarch64-darwin/build lunar`.
- Basic Pi extension loadability via `pi --offline --no-session -e ./agents/targets/pi/extensions/landing-workflow/index.ts -p "/land"`.

### Follow-up

- To make the extension live in the installed wrapper, apply the built generation with your normal darwin switch flow.
