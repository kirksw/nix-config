# feat-herdr-pi-skill

> Add a local patched pi-herdr package with the extension plus skill for reliable herdr pane, tab, and workspace orchestration.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

Historical pi sessions from this week showed agents repeatedly probing `herdr` through shell commands and installed package docs before acting. The native `herdr` pi extension already toggles its tool registration based on `HERDR_ENV`/`HERDR_PANE_ID`, but the package did not also provide a skill that teaches the native-tool workflow.

Evidence:

- `019f3397-5d0b-7e0f-9f84-c003c5a8143d`: installed/read upstream herdr skill and asked about toggling cmux/herdr skills.
- `019f374f-c118-7a18-8a1d-ed5a1e02f331`: checked cmux/herdr availability, ran `herdr workspace --help`, and tried direct workspace focus from shell.
- `019f372c-ee68-7238-9f58-dfef58720826`: probed herdr CLI help while adding shim support.
- `019f3213-f93d-73d0-a79b-dacdabeb1e76`: repeatedly used `bash herdr ...` while building herdr palette helpers.

## Plan

### Scope

- `agents/packages/pi-herdr/index.ts`
- `agents/packages/pi-herdr/package.json`
- `agents/packages/pi-herdr/skills/herdr/SKILL.md`
- `agents/base-settings.nix`

### Approach

1. Create a local patched pi package from the installed `@ogulcancelik/pi-herdr` extension.
2. Add package metadata that loads both `./index.ts` and `./skills`.
3. Add a lean skill focused on native pi `herdr` tool usage.
4. Point pi settings at the local package path instead of `npm:@ogulcancelik/pi-herdr`.

### Risks

- The local extension copy can drift from upstream `@ogulcancelik/pi-herdr`.
- The skill intentionally stays minimal and does not mirror the full herdr CLI reference.

## Testing

Commands run to validate:

```sh
nixfmt --check agents/base-settings.nix agents/presets/default.nix
./scripts/check-structure.sh
nix run .#sync-agents
```

Result:

- `nixfmt --check` passed for changed Nix files.
- `nix run .#sync-agents` completed and synced pi/claude/codex/opencode configs.
- `./scripts/check-structure.sh` failed on pre-existing unrelated sorted-import issues:
  - `modules/home/imports.nix must be sorted lexicographically`
  - `modules/shared/imports.nix must be sorted lexicographically`

## Summary

### What changed

- Added local patched `agents/packages/pi-herdr` package.
- Package preserves the upstream extension's environment-gated tool registration and adds `skills/herdr/SKILL.md`.
- Replaced `npm:@ogulcancelik/pi-herdr` with the local package path in pi settings.

### What was tested

- Changed Nix files format-check successfully.
- Agent configs synced successfully.
- Repository structure check was attempted and failed on unrelated import sorting.

### Follow-up

- None.
