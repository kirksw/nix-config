# feat-documentation-refactor

> Reduce top-level agent guidance to a map and guardrails.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`AGENTS.md` mixed repository navigation, operational commands, agent workflow, and backlog policy. Keep the entrypoint small while preserving high-risk guardrails and linking canonical guidance.

## Plan

### Scope

- `AGENTS.md`
- `docs/agents/README.md`
- `docs/agents/nix-flake-ops.md`
- `agents/defs/skills/nix-agents/references/flake-ops.md`
- `docs/BACKLOG.md`

### Approach

1. Replace top-level procedural detail with links and critical guardrails.
2. Put workflow and backlog policy in their existing canonical documents.
3. Keep operational commands and the macOS-to-Linux deploy-rs warning in the flake operations guidance.
4. Validate links, whitespace, and repository structure.

### Risks

- Existing uncommitted changes in `AGENTS.md` must remain preserved.
- Documentation links can silently stale if paths move.

## Testing

Commands run to validate:

```sh
python3 - <<'PY'  # inline local-Markdown-link check
# parse local links in the six changed Markdown files and verify targets exist
PY
git diff --check
./scripts/check-structure.sh
nix flake check --no-build
```

Results:

- Local Markdown link/path check passed for all six changed documentation files.
- `git diff --check` passed.
- `./scripts/check-structure.sh` passed.
- A read-only `bottleneck` subagent validated that the failure-feedback rule would require the earlier macOS local-build mistake to produce a reviewed documentation/guardrail correction. It also confirmed the deploy-rs commands match `flake/deploy.nix`; the rule remediates recurrence but cannot prevent a first occurrence by itself.
- `nix flake check --no-build` reached the existing deploy checks but failed evaluating the unrelated `openclaw` store path (`path '3h1nr8ya5zn3ca7llbdzbmdnvsflvq9c-openclaw' is not valid`).

## Summary

### What changed

- Reduced `AGENTS.md` to a repository map and critical guardrails.
- Moved agent workflow and backlog policy to their canonical docs.
- Consolidated operational commands and deploy-rs safety guidance in flake operations references.

### What was tested

- Local Markdown link/path validation.
- `git diff --check`.
- `./scripts/check-structure.sh`.
- `nix flake check --no-build` attempted; blocked by the unrelated existing `openclaw` store-path evaluation failure noted above.

### Follow-up

- None.
