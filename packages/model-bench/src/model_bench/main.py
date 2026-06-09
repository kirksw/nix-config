from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from .challenges import Challenge, discover_challenges, render_prompt
from .config import data_dir, default_results_dir, load_config, parse_model_list, parse_model_overrides, resolve_model, resolve_thinking
from .pi_runner import run_pi
from .reporter import append_jsonl, format_trend, read_history, summarize, timestamp, write_json, write_leaderboard
from .sources import default_repo_cache_dir, materialize_source
from .verifiers import verification_to_json, verify


def build_parser() -> argparse.ArgumentParser:
    root = data_dir()
    parser = argparse.ArgumentParser(description="Tier-aware LLM model assessor for Pi agent roles")
    parser.add_argument("--data-dir", type=Path, default=root, help="model-bench data directory")
    parser.add_argument("--config", type=Path, default=None, help="tier override TOML")
    parser.add_argument("--challenges-dir", type=Path, default=None, help="challenge TOML directory")
    parser.add_argument("--fixtures-dir", type=Path, default=None, help="fixture directory")
    parser.add_argument("--results-dir", type=Path, default=default_results_dir(), help="directory for local run results")
    parser.add_argument("--pi-bin", default=os.environ.get("MODEL_BENCH_PI_BIN", "pi"), help="Pi binary/wrapper to execute")
    parser.add_argument("--repo-cache-dir", type=Path, default=default_repo_cache_dir(), help="cache directory for git-backed challenge sources")
    parser.add_argument("--verifier-model", default="openai-codex/gpt-5.5", help="default model for agent-binary verifiers")
    parser.add_argument("--verifier-thinking", default="high", help="default thinking level for agent-binary verifiers")
    parser.add_argument("--verifier-tools", default="read,grep,find,ls", help="default tools for agent-binary verifiers")
    parser.add_argument("--models", default=None, help="comma-separated tier=model overrides")
    parser.add_argument("--compare-models", default=None, help="comma-separated model IDs to run against each selected challenge")
    parser.add_argument("--challenge", action="append", default=[], help="challenge id to run; repeatable")
    parser.add_argument("--agent", action="append", default=[], help="agent name to run; repeatable")
    parser.add_argument("--tier", action="append", default=[], help="tier name to run; repeatable")
    parser.add_argument("--runs", type=int, default=None, help="override runs per challenge")
    parser.add_argument("--timeout", type=int, default=None, help="override timeout per run in seconds")
    parser.add_argument("--list-challenges", action="store_true", help="list loaded challenges and exit")
    parser.add_argument("--dry-run", action="store_true", help="show planned runs without invoking Pi")
    parser.add_argument("--trend", action="store_true", help="show recent result history and exit")
    parser.add_argument("--history-limit", type=int, default=10, help="number of history entries to show with --trend")
    return parser


def _paths(args: argparse.Namespace) -> tuple[Path, Path, Path, Path]:
    root = args.data_dir
    config = args.config or (root / "tier-overrides.toml")
    challenges_dir = args.challenges_dir or (root / "challenges")
    fixtures_dir = args.fixtures_dir or (root / "fixtures")
    return root, config, challenges_dir, fixtures_dir


def _filter_challenges(challenges: list[Challenge], args: argparse.Namespace) -> list[Challenge]:
    selected = challenges
    if args.challenge:
        allowed = set(args.challenge)
        selected = [item for item in selected if item.challenge_id in allowed]
    if args.agent:
        allowed = set(args.agent)
        selected = [item for item in selected if item.agent in allowed]
    if args.tier:
        allowed = set(args.tier)
        selected = [item for item in selected if item.tier in allowed]
    return selected


def _print_challenges(challenges: list[Challenge]) -> None:
    print("| Challenge | Tier | Agent | Runs | Description |")
    print("|---|---|---|---:|---|")
    for item in challenges:
        print(f"| {item.challenge_id} | {item.tier} | {item.agent} | {item.runs} | {item.description} |")


def _models_for_challenge(challenge: Challenge, config, args: argparse.Namespace) -> list[str]:
    compare_models = parse_model_list(args.compare_models)
    if compare_models:
        return compare_models
    return [resolve_model(config, challenge.tier)]


def _planned_runs(challenges: list[Challenge], config, args: argparse.Namespace) -> list[dict]:
    planned: list[dict] = []
    for challenge in challenges:
        runs = args.runs if args.runs is not None else challenge.runs
        thinking = resolve_thinking(config, challenge.tier, challenge.thinking)
        for model in _models_for_challenge(challenge, config, args):
            for run_index in range(1, runs + 1):
                planned.append(
                    {
                        "challengeId": challenge.challenge_id,
                        "tier": challenge.tier,
                        "agent": challenge.agent,
                        "model": model,
                        "thinking": thinking,
                        "runIndex": run_index,
                    }
                )
    return planned


def _validate_args(args: argparse.Namespace) -> None:
    if args.runs is not None and args.runs <= 0:
        raise ValueError("--runs must be > 0")
    if args.timeout is not None and args.timeout <= 0:
        raise ValueError("--timeout must be > 0")


def _failure_record(
    *,
    run_id: str,
    challenge: Challenge,
    model: str,
    thinking: str,
    run_index: int,
    wall_seconds: float,
    error: str,
    stderr: str,
) -> dict:
    return {
        "runId": run_id,
        "challengeId": challenge.challenge_id,
        "tier": challenge.tier,
        "agent": challenge.agent,
        "model": model,
        "thinking": thinking,
        "runIndex": run_index,
        "passed": False,
        "score": 0.0,
        "wallSeconds": round(wall_seconds, 4),
        "firstTextSeconds": None,
        "outputChars": 0,
        "eventCount": 0,
        "returncode": -1,
        "stderr": stderr[-2000:],
        "verification": {"passed": False, "score": 0.0, "details": {"error": error}},
        "output": "",
    }


def _run(args: argparse.Namespace) -> int:
    _validate_args(args)
    _, config_path, challenges_dir, fixtures_dir = _paths(args)
    config = load_config(config_path, parse_model_overrides(args.models))
    challenges = _filter_challenges(discover_challenges(challenges_dir, fixtures_dir), args)

    if args.list_challenges:
        _print_challenges(challenges)
        return 0

    if not challenges:
        print("No challenges selected", file=sys.stderr)
        return 2

    planned = _planned_runs(challenges, config, args)
    if args.dry_run:
        print(json.dumps({"config": str(config_path), "plannedRuns": planned}, indent=2))
        return 0

    run_id = timestamp()
    run_dir = args.results_dir / run_id
    run_dir.mkdir(parents=True, exist_ok=False)
    records: list[dict] = []
    run_jsonl = run_dir / "run.jsonl"

    source_cwds: dict[str, Path] = {}
    with tempfile.TemporaryDirectory(prefix="model-bench-work-") as tmp:
        default_cwd = Path(tmp)
        for challenge in challenges:
            source_cwds[challenge.challenge_id] = materialize_source(challenge.source, args.repo_cache_dir) or default_cwd

        total = len(planned)
        index = 0
        for challenge in challenges:
            runs = args.runs if args.runs is not None else challenge.runs
            timeout = args.timeout if args.timeout is not None else challenge.timeout_seconds
            thinking = resolve_thinking(config, challenge.tier, challenge.thinking)
            cwd = source_cwds[challenge.challenge_id]
            prompt = render_prompt(challenge, cwd)
            for model in _models_for_challenge(challenge, config, args):
                for run_index in range(1, runs + 1):
                    index += 1
                    print(f"[{index}/{total}] {challenge.challenge_id} via {model} ({thinking})", flush=True)
                    try:
                        pi_result = run_pi(
                            pi_bin=args.pi_bin,
                            model=model,
                            thinking=thinking,
                            prompt=prompt,
                            cwd=cwd,
                            timeout_seconds=timeout,
                            tools=challenge.tools,
                        )
                        verification = verify(
                            pi_result.output,
                            challenge.verifier,
                            fixtures_dir,
                            cwd=cwd,
                            pi_bin=args.pi_bin,
                            verifier_model=args.verifier_model,
                            verifier_thinking=args.verifier_thinking,
                            verifier_tools=args.verifier_tools,
                        )
                        record = {
                            "runId": run_id,
                            "challengeId": challenge.challenge_id,
                            "tier": challenge.tier,
                            "agent": challenge.agent,
                            "model": model,
                            "thinking": thinking,
                            "runIndex": run_index,
                            "passed": verification.passed and pi_result.returncode == 0,
                            "score": verification.score if pi_result.returncode == 0 else 0.0,
                            "wallSeconds": round(pi_result.wall_seconds, 4),
                            "firstTextSeconds": None if pi_result.first_text_seconds is None else round(pi_result.first_text_seconds, 4),
                            "outputChars": len(pi_result.output),
                            "eventCount": pi_result.events,
                            "returncode": pi_result.returncode,
                            "stderr": pi_result.stderr[-2000:],
                            "verification": verification_to_json(verification),
                            "output": pi_result.output,
                        }
                    except subprocess.TimeoutExpired as exc:
                        record = _failure_record(
                            run_id=run_id,
                            challenge=challenge,
                            model=model,
                            thinking=thinking,
                            run_index=run_index,
                            wall_seconds=timeout,
                            error="timeout",
                            stderr=str(exc),
                        )
                    except Exception as exc:
                        record = _failure_record(
                            run_id=run_id,
                            challenge=challenge,
                            model=model,
                            thinking=thinking,
                            run_index=run_index,
                            wall_seconds=0.0,
                            error=exc.__class__.__name__,
                            stderr=str(exc),
                        )
                    records.append(record)
                    append_jsonl(run_jsonl, record)

    summary = summarize(run_id, records)
    write_json(run_dir / "summary.json", summary)
    write_leaderboard(run_dir / "leaderboard.md", summary)
    args.results_dir.mkdir(parents=True, exist_ok=True)
    append_jsonl(args.results_dir / "history.jsonl", summary)

    print(f"Results: {run_dir}")
    print(f"Leaderboard: {run_dir / 'leaderboard.md'}")
    print(f"Pass rate: {summary['totals']['passRate']} median score: {summary['totals']['medianScore']}")
    return 0 if summary["totals"]["passRate"] == 1.0 else 1


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.trend:
        print(format_trend(read_history(args.results_dir / "history.jsonl", args.history_limit)))
        return 0
    try:
        return _run(args)
    except (KeyError, ValueError, FileNotFoundError) as exc:
        print(f"model-bench: {exc}", file=sys.stderr)
        return 2
