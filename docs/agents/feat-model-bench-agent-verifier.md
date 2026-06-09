# feat-model-bench-agent-verifier

> Upgrade model-bench scout evaluation to use repo-scale inputs and agent-verified binary criteria.

## Status

- [x] Plan
- [ ] Implement
- [ ] Test
- [ ] Complete

## Context

The initial scout benchmark used a small log fixture and regex scoring. It was useful for harness validation but too easy for model comparison. Scout should be evaluated against repository-scale context gathering, and quality metrics should be binary criteria judged independently from runtime performance metrics.

## Plan

### Scope

- `packages/model-bench/` runner, challenge schema, verifier schema, README, and scout challenge.
- `docs/agents/feat-model-bench-agent-verifier.md` completion notes.

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
# filled during implementation
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._
