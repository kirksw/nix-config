# model-bench

Tier-aware LLM model assessor for Pi agent roles.

The benchmark runs one starter challenge per agent role and scores candidate models on output quality and speed. It is intentionally local-first: prompts and verifiers are versioned in this package, while run results are written to `~/.local/share/model-bench/results` by default.

## Usage

```sh
nix run .#model-bench -- --list-challenges
nix run .#model-bench -- --dry-run
nix run .#model-bench -- --models fast=openai-codex/gpt-5.4-mini,ultrafast=minimax/minimax-m2.7-highspeed
nix run .#model-bench -- --tier fast --compare-models minimax/minimax-m2.7-highspeed,openai-codex/gpt-5.4-mini,openai-codex/gpt-5.3-codex-spark
nix run .#model-bench -- --trend
```

By default the runner calls `pi` from `PATH`. Use `--pi-bin /path/to/pi` or set `MODEL_BENCH_PI_BIN` if you need a specific wrapper.

The Pi invocation is non-interactive JSON mode:

```sh
pi --mode json --no-session --no-tools --model <provider/model> --thinking <level> <prompt>
```

## Model configuration

Edit `tier-overrides.toml` or pass `--models` to change the model used for a tier. Use `--compare-models model1,model2,...` to run every selected challenge against each candidate model in one sweep.

Resolution order:

1. `--models tier=model` CLI overrides
2. `tier-overrides.toml`
3. fail loudly

The first version intentionally does not parse Nix `profiles.nix`; keeping the benchmark override explicit avoids ambiguity while A/B testing.

## Results

Each run creates a timestamped directory:

```text
~/.local/share/model-bench/results/<timestamp>/
├── run.jsonl
├── summary.json
└── leaderboard.md
```

A compact summary is also appended to `~/.local/share/model-bench/results/history.jsonl` for trend comparisons.

## Challenge format

Challenges are TOML files with:

- `[challenge]` — id, tier, agent, runs, timeout.
- `[prompt]` — prompt text; supports `{{fixture:path/to/file}}` substitutions.
- `[verifier]` — verifier type and options.

Verifier types:

- `regex` — scores required/forbidden regular expressions.
- `python-unittest` — extracts a Python code block, writes it to `solution.py`, rejects configured dangerous code patterns, and runs a stdlib unittest fixture with `python3 -I`.

> Security note: `python-unittest` still executes model-generated code on the host. It is intended for trusted local evaluation only. Keep code challenges small, pure, and guarded with `forbiddenCodeRegex` patterns.
