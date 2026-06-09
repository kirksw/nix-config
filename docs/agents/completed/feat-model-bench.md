# feat-model-bench

> Add a tier-aware LLM model assessor for Pi personal agent model evaluation.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The personal Pi profile maps agent tiers to models, but there is no repeatable way to compare candidate models against the actual work assigned to each tier. A generic coding challenge would not reflect the roles of agents such as `scout`, `scribe`, `code-red`, or `the-architect`.

This feature adds a reusable benchmark harness that evaluates models by tier using role-specific challenges and records comparable performance and quality metrics over time.

## Plan

### Scope

Affected files/modules:

- `packages/model-bench/` — new package and benchmark runner.
- `docs/agents/completed/feat-model-bench.md` — completed feature plan and summary.
- `docs/BACKLOG.md` — follow-up items discovered during implementation/review.

### Approach

1. Add a Python stdlib-only package `model-bench` with `meta.mainProgram = "model-bench"` so `nix run .#model-bench` works.
2. Use Pi's documented non-interactive JSON mode:
   - `pi --mode json --no-session --no-tools --model <provider/model> --thinking <level> <prompt>`.
3. Resolve tier models from `tier-overrides.toml`, with CLI overrides via `--models tier=model`.
4. Add `--compare-models model1,model2,...` to run the same selected challenge(s) against candidate models in one sweep.
5. Add one starter challenge per agent role:
   - `scribe`, `scout`, `explore`, `code-monkey`, `chaos-demon`, `bottleneck`, `code-red`, `the-architect`, `10xBEAST`.
6. Add verifiers for regex/structure checks and a guarded stdlib `unittest`-based Python code challenge.
7. Write timestamped local results under `~/.local/share/model-bench/results` by default and append summaries to `history.jsonl`.
8. Add `--trend`, `--list-challenges`, `--dry-run`, challenge/agent/tier filtering, and repeat/timeout controls.

### Risks

- Pi JSON mode may not expose token usage directly. Mitigation: record wall time, time-to-first-text delta, output character count, and event count.
- Model variance can make single-run results noisy. Mitigation: support configurable repeated runs and report medians.
- API rate limits or auth issues may interrupt long sweeps. Mitigation: run sequentially by default and persist each run record.
- Text verifiers are imperfect proxies for review/design quality. Mitigation: keep challenge/verifier TOML editable and store raw outputs for manual inspection.
- `python-unittest` executes model-generated code. Mitigation: run in a temp dir with `python3 -I`, reject configured dangerous code patterns, document the limitation, and add a backlog item for stronger sandboxing.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix build .#model-bench --no-link
nix run .#model-bench -- --list-challenges
nix run .#model-bench -- --dry-run --tier fast --compare-models minimax/minimax-m2.7-highspeed,openai-codex/gpt-5.4-mini,openai-codex/gpt-5.3-codex-spark
nix run .#model-bench -- --pi-bin "$tmpdir/fake-pi" --challenge scout-log-anomalies --compare-models model-a,model-b --results-dir "$results"
nix flake check --no-build
```

Review gates:

- `bottleneck` reviewed the implementation and identified subprocess timeout, history parsing, challenge loading, and code-execution risks.
- `chaos-demon` reviewed failure modes around subprocess hangs, history corruption, run-id collisions, malformed challenges, and metric integrity.
- Follow-up fixes were implemented in commit `371aa6b`.

## Summary

### What changed

- Added `packages/model-bench`, a Nix-packaged Python CLI for tier-aware model assessment.
- Added role-specific starter challenges and fixtures for nine agent roles.
- Added model tier overrides and compare-mode candidate sweeps.
- Added Pi JSON-mode invocation with wall-time and first-text timing.
- Added local result persistence: `run.jsonl`, `summary.json`, `leaderboard.md`, and `history.jsonl`.
- Added verifier strategies for regex/structure scoring and guarded Python unittest execution.

### What was tested

- Package builds through Nix.
- Flake evaluation succeeds with `nix flake check --no-build`.
- Challenge discovery and dry-run planning work through `nix run`.
- Fake Pi JSON-mode execution writes results and produces a passing summary.

### Follow-up

Added to `docs/BACKLOG.md`:

- P2 M Add a stronger sandbox for `model-bench` code-execution verifiers on macOS/Linux.
- P2 S Teach `model-bench` to import live profile tier mappings from nix-agents metadata as a fallback to `tier-overrides.toml`.
- P3 S Add more fixture variants per agent role to reduce overfitting in `model-bench` results.
