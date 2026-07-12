# feat-repository-hygiene

> Reduce repository clutter and documentation debt while restoring a green structural baseline.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The repository structure check was red, obsolete and generated artifacts
remained visible, several documents disagreed with live configuration, and Nix
guidance was duplicated between documentation and executable agent skills.

## Plan

### Scope

Import manifests, confirmed obsolete artifacts, ignore rules, repository-facing
documentation, backlog entries, and duplicated agent guidance.

### Approach

1. Restore lexicographic import ordering and remove confirmed dead artifacts.
2. Ignore local Pi subagent runtime output without deleting user files.
3. Reconcile documentation and backlog claims against live configuration.
4. Make executable agent skills canonical and retain thin documentation links.
5. Run structure, flake, sync, diff, and canonical-target validation.

### Risks

- Removing an artifact that is still operational would break a workflow; references were checked first.
- Backlog follow-ups may remain valid after their parent feature completes; only disproved claims were closed.
- Documentation consolidation preserved human-facing pointer pages.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
git diff --check
git check-ignore -v .pi-subagents/
```

All commands passed. Canonical documentation link targets and the current
secrets inventory were also checked against the filesystem.

## Summary

### What changed

- Restored sorted module manifests and a green structural baseline.
- Removed two tracked backup files and obsolete team-dashboard artifacts.
- Ignored `.pi-subagents/` while preserving its existing local contents.
- Corrected the MCP name and secrets inventory, and closed two disproved backlog items.
- Replaced duplicated agent guidance with stable pointers to executable skill sources.

### What was tested

- Repository structure and diff hygiene.
- Full flake evaluation without builds.
- Generated agent-profile synchronization.
- Ignore behavior and documentation target existence.

### Follow-up

- The existing `docs/BACKLOG.md` item tracks mechanical knowledge-store validation.
