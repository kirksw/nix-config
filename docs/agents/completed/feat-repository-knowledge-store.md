# feat-repository-knowledge-store

> Establish a minimal, repository-local knowledge store for progressive disclosure.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repository already contained agent plans, ADRs, references, and a backlog,
but lacked a single knowledge index, a top-level architecture map, and a home
for general design documents and execution plans. The layout follows the
repository-knowledge pattern described in OpenAI's Harness Engineering article
without migrating or duplicating established documentation.

## Plan

### Scope

Add navigation and general knowledge categories under `docs/`, link them from
`AGENTS.md`, and preserve existing specialized workflows.

### Approach

1. Inventory existing documentation and identify reusable sources of truth.
2. Add architecture, knowledge-store, design, and execution-plan indexes.
3. Record stable core beliefs and one validation follow-up.
4. Validate structure, links, and flake evaluation.

### Risks

- Empty categories can become stale; only categories with an explicit purpose were added.
- Duplicating agent plans would create competing sources of truth, so they remain under `docs/agents/`.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh  # failed: pre-existing unsorted module manifests
nix flake check --no-build   # passed
git diff --check             # passed
```

## Summary

### What changed

- Added `ARCHITECTURE.md` and `docs/README.md` as stable navigation maps.
- Added indexed design principles and general active/completed plan locations.
- Linked existing ADR, agent, reference, secrets, and backlog documentation instead of moving it.

### What was tested

- Repository structure check.
- Flake evaluation without builds.
- Local Markdown link targets.

`scripts/check-structure.sh` reported that `modules/home/imports.nix` and
`modules/shared/imports.nix` are not lexicographically sorted. Neither file is
part of this change.

### Follow-up

- `docs/BACKLOG.md` tracks a mechanical knowledge-store validation check.
