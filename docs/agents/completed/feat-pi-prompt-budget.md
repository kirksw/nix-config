# feat-pi-prompt-budget

> Reduce Pi's default first-turn prompt cost while preserving the current capability set behind an explicit full profile.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

A clean Pi session that only handled `hello` reported 17,156 input tokens, 11 output tokens, and no cache read.
The exported session contained a 35,463-character system prompt and 65,897 characters of schemas for 34 tools.
The largest avoidable contributors were the 41-skill catalog, repeated tool guidance, Context Mode, browser automation, and verbose subagent schemas.
The default profile needed a measurable prompt budget and a stable full-capability escape hatch before its resource surface was reduced.

## Plan

### Scope

- Add deterministic export analysis under `scripts/`.
- Add lean and full Pi package settings in `agents/base-settings.nix`.
- Add explicit lean and full resource profiles in `agents/presets/profiles.nix`.
- Update profile selection and generated profile synchronization in `modules/home/programs/ai-agents.nix` and `flake/apps.nix`.
- Consolidate repeated guidance in `agents/AGENTS.md` and local Pi packages.
- Preserve existing uncommitted changes in touched files.

### Approach

1. Add an analyzer that decodes Pi HTML exports and reports first-turn and latest-turn input tokens, prompt sections, skills, tools, schema families, and configurable budgets without making model calls.
2. Preserve the current package, agent, and skill surface as `personal-full` before changing the default.
3. Support the full profile through `pix --profile full`, `NIX_AGENTS_PROFILE=personal-full pi`, and `.nix-agents-profile`.
4. Reduce always-on Herdr, todo, journal, and global-context guidance without weakening runtime validation or execution gates.
5. Give `personal-default` explicit high-frequency agent and skill allowlists while retaining the complete catalogs in `personal-full`.
6. Give the personal default a stable lean package set and move Context Mode, browser automation, and agent journal to the full base.
7. Regenerate profiles through Nix, run targeted tests, and measure a clean first turn against a 10,000-token hard limit and a 9,000-token target.

### Risks

- Base settings are shared by profiles, so distinct package surfaces require separate bases.
- Removing Context Mode from the lean profile trades lower prompt cost for less efficient processing of unusually large inputs.
- Reducing visible agents or skills can make occasional capabilities less discoverable even when `personal-full` retains them.
- Third-party package schemas may require upstream changes if future additions exceed the budget.
- CLI re-exports can omit captured prompt and tool metadata, so provider-reported first-turn input tokens remain authoritative.
- Prompt savings vary by provider tokenizer and must be measured with the production model.

## Testing

Commands run to validate:

```sh
node --test scripts/analyze-pi-export.test.mjs
node scripts/analyze-pi-export.mjs /tmp/pi-prompt-budget-lean.html --max-input-tokens 10000
npm test --prefix agents/packages/pi-todo
npm test --prefix agents/packages/pi-agent-journal
npm run typecheck --prefix agents/packages/pi-todo
npm run typecheck --prefix agents/packages/pi-agent-journal
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents -- --dry-run
nix run .#sync-agents
nix build .#darwinConfigurations.lunar.config.system.build.toplevel --no-link
```

The package tests and typechecks ran from temporary package copies after installing their declared development dependencies, because the source directories intentionally do not contain `node_modules`.

## Summary

### What changed

- Added `scripts/analyze-pi-export.mjs` with tests and configurable prompt budgets.
- Added a `personal-full` base and profile with the previous 20-package, nine-agent, and 32-generated-skill surface.
- Reduced `personal-default` to 17 packages, five agents, and eight generated skills.
- Removed Context Mode, agent journal, and Bladebro from the lean package surface while retaining web research, todo, ask-user, subagents, recall, Herdr, permissions, and tracing.
- Consolidated duplicated global, Herdr, todo, and journal prompt guidance.
- Added strict profile validation and full-profile selection through `pix` and `NIX_AGENTS_PROFILE`.

### What was tested

- The analyzer's five tests passed and reproduced the 17,156-token baseline.
- A clean lean `openai-codex/gpt-5.6-sol` session reported 7,999 first-turn input tokens, a reduction of 9,157 tokens or approximately 53%.
- The lean profile passed the 10,000-token hard limit and the 9,000-token target.
- All 237 todo tests, four agent-journal tests, and both package typechecks passed.
- Structure checks, flake evaluation, generated-profile synchronization, and the Darwin system build passed.
- Generated settings confirmed that the lean profile excludes Context Mode, agent journal, and Bladebro while `personal-full` retains them.

### Follow-up

- No follow-up work is required.
