# feat-model-bench

> Add a tier-aware LLM model assessor for Pi personal agent model evaluation.

## Status

- [x] Plan
- [ ] Implement
- [ ] Test
- [ ] Complete

## Context

The personal Pi profile maps agent tiers to models, but there is no repeatable way to compare candidate models against the actual work assigned to each tier. A generic coding challenge would not reflect the roles of agents such as `scout`, `scribe`, `code-red`, or `the-architect`.

This feature adds a reusable benchmark harness that evaluates models by tier using role-specific challenges and records comparable performance and quality metrics over time.

## Plan

### Scope

Affected files/modules:

- `packages/model-bench/` — new package and benchmark runner.
- `flake/packages.nix` — no direct wiring expected; packages are auto-discovered by `packages/*/default.nix`.
- `docs/agents/feat-model-bench.md` — feature plan and completion record.

### Approach

1. Add a Python stdlib-only package `model-bench` with `meta.mainProgram = "model-bench"` so `nix run .#model-bench` works.
2. Use Pi's documented non-interactive JSON mode:
   - `pi --mode json --no-session --model <provider/model> --thinking <level> --no-tools <prompt>`.
3. Resolve tier models from `tier-overrides.toml` first, with entries matching current Pi personal candidate models.
4. Add one starter challenge per agent role:
   - `scribe`, `scout`, `explore`, `code-monkey`, `chaos-demon`, `bottleneck`, `code-red`, `the-architect`, `10xBEAST`.
5. Add verifiers for regex/structure checks and a stdlib `unittest`-based Python code challenge.
6. Write timestamped local results under `~/.local/share/model-bench/results` by default and append summaries to `history.jsonl`.
7. Add `--trend`, `--list-challenges`, `--dry-run`, and CLI overrides for tiers/results/runs.

### Risks

- Pi JSON mode may not expose first-token timestamps or token usage directly. Mitigation: record wall time, output character count, event count, and first observed text delta time when present.
- Model variance can make single-run results noisy. Mitigation: support configurable repeated runs and report medians.
- API rate limits or auth issues may interrupt long sweeps. Mitigation: run sequentially by default and persist each run record.
- Text verifiers are imperfect proxies for review/design quality. Mitigation: keep challenge/verifier TOML editable and store raw outputs for manual inspection.

## Testing

Commands run to validate:

```sh
# filled during implementation
```

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- ...

### What was tested

- ...

### Follow-up

- Any remaining work or future improvements.
- All follow-up items must be added to `docs/BACKLOG.md` with priority and effort estimate.
