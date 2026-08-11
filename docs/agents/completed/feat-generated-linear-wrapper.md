# feat-generated-linear-wrapper

> Replace the partial handwritten Linear helper with MCPorter's complete generated CLI.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The prior Linear script wrapped only four read paths despite the Linear MCP exposing a much larger schema surface.
It was hand-written after an initial schema inspection and did not meet the requirement for deterministic full API coverage.

## What changed

- Generated `agents/defs/skills/linear/generated/linear.mjs` with `mcporter generate-cli linear --runtime node --bundle ... --minify`.
- The artifact embeds the resolved Linear server definition and schemas for 63 Linear operations.
- Added `scripts/run.mjs`, which forwards every generated command and flag, bounds printed JSON for Context Mode, and requires `LINEAR_WRITE_CONFIRMED=1` after explicit user confirmation for operations with mutating prefixes.
- Updated `SKILL.md` with generated-command usage and the exact regeneration command.
- Added a narrow `.gitattributes` whitespace exemption for MCPorter's generated parser literals, which contain intentional whitespace that otherwise fails `git diff --check`.

## Testing

- `node generated/linear.mjs __mcporter_inspect` reports MCPorter 0.13.3.
- Generated CLI help reports 63 tools.
- Generated `get-user`, `get-issue`, and installed Context Mode runner checks succeeded.
- Mutation guard rejected an unconfirmed `delete-comment` call.
- `./scripts/check-structure.sh`, `git diff --check`, `git diff --cached --check`, and `nix flake check --no-build --option eval-cache false` passed.

## Follow-up

Restart Pi to load the updated Linear skill.
Regenerate the artifact when Linear's MCP schema changes.
