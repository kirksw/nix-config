# feat-model-bench-agent-verifier

> Upgrade model-bench scout evaluation to use repo-scale inputs and agent-verified binary criteria.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The initial scout benchmark used a small log fixture and regex scoring. It was useful for harness validation but too easy for model comparison. Scout should be evaluated against repository-scale context gathering, and quality metrics should be binary criteria judged independently from runtime performance metrics.

## Plan

### Scope

- `packages/model-bench/` runner, challenge schema, verifier schema, README, and scout challenge.
- `docs/agents/completed/feat-model-bench-agent-verifier.md` completion notes.
- `docs/BACKLOG.md` follow-up calibration item.

### Approach

1. Add challenge-level git sources so benchmarks can clone/cache external repositories without vendoring them.
2. Allow selected challenges to run Pi with read/search tools instead of always using `--no-tools`.
3. Replace the scout log challenge with a pinned Apache Fluss repository reconnaissance challenge.
4. Add an `agent-binary` verifier that uses a separate verifier model to judge explicit binary criteria and returns structured JSON.
5. Keep performance metrics separate from quality metrics: candidate wall time and first-text latency remain from the candidate run only.
6. Add CLI knobs for verifier model, verifier thinking level, verifier tools, and repository cache directory.

### Risks

- External git clones can be slow or fail offline. Mitigation: cache cloned repositories under `~/.cache/model-bench/repos`.
- LLM-as-judge can be inconsistent. Mitigation: require binary criteria with evidence/reason and persist verifier output.
- Verifier calls increase cost and latency. Mitigation: make verifier model configurable and keep performance metrics scoped to candidate runs.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix build .#model-bench --no-link
nix run .#model-bench -- --list-challenges
nix run .#model-bench -- --dry-run --tier fast --compare-models minimax/minimax-m2.7-highspeed,openai-codex/gpt-5.4-mini,openai-codex/gpt-5.5
nix run .#model-bench -- --pi-bin "$tmpdir/fake-pi" --challenge scout-fluss-repo --results-dir "$results" --repo-cache-dir "$cache" --verifier-model judge-model
nix run .#model-bench -- --tier fast --compare-models minimax/minimax-m2.7-highspeed,openai-codex/gpt-5.4-mini,openai-codex/gpt-5.5 --runs 1
nix flake check --no-build
```

## Summary

### What changed

- Added git-backed challenge sources with cached clone/fetch support.
- Added candidate-run tool selection through challenge `tools`.
- Added `agent-binary` verifier using a separate Pi model to judge binary criteria.
- Replaced the toy scout log challenge with a pinned Apache Fluss repository reconnaissance challenge.
- Added explicit binary scout criteria such as purpose identification, module path coverage, versioned connector awareness, Maven/test-layout detection, no em-dashes, no fix suggestions, and concrete path evidence.

### What was tested

- Nix package build.
- Challenge discovery and dry-run planning.
- Fake Pi execution covering git source materialization and agent-binary verifier parsing.
- Real one-run fast/scout comparison across the three candidate models.
- `nix flake check --no-build`.

### Follow-up

Added to `docs/BACKLOG.md`:

- P2 S Calibrate `model-bench` agent-binary criteria with harder scout repos and known-good/known-bad outputs.
