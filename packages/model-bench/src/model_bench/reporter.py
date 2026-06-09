from __future__ import annotations

import json
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def append_jsonl(path: Path, value: Any) -> None:
    with path.open("a") as fh:
        fh.write(json.dumps(value, sort_keys=True) + "\n")


def median(values: list[float]) -> float | None:
    if not values:
        return None
    return round(float(statistics.median(values)), 4)


def summarize(run_id: str, records: list[dict]) -> dict:
    by_challenge: dict[str, list[dict]] = defaultdict(list)
    by_tier: dict[str, list[dict]] = defaultdict(list)
    by_model: dict[str, list[dict]] = defaultdict(list)

    for record in records:
        by_challenge[record["challengeId"]].append(record)
        by_tier[record["tier"]].append(record)
        by_model[record["model"]].append(record)

    def aggregate(items: list[dict]) -> dict:
        scores = [float(item["score"]) for item in items]
        wall = [float(item["wallSeconds"]) for item in items]
        ttft = [float(item["firstTextSeconds"]) for item in items if item.get("firstTextSeconds") is not None]
        passed = [item for item in items if item["passed"]]
        return {
            "runs": len(items),
            "passRate": round(len(passed) / len(items), 4) if items else 0.0,
            "medianScore": median(scores),
            "medianWallSeconds": median(wall),
            "medianFirstTextSeconds": median(ttft),
        }

    return {
        "runId": run_id,
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "totals": aggregate(records),
        "byChallenge": {key: aggregate(value) for key, value in sorted(by_challenge.items())},
        "byTier": {key: aggregate(value) for key, value in sorted(by_tier.items())},
        "byModel": {key: aggregate(value) for key, value in sorted(by_model.items())},
    }


def write_leaderboard(path: Path, summary: dict) -> None:
    lines = [
        f"# model-bench leaderboard — {summary['runId']}",
        "",
        "## Totals",
        "",
        _row(summary["totals"]),
        "",
        "## By tier",
        "",
        "| Tier | Runs | Pass rate | Median score | Median wall | Median first text |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for tier, agg in summary["byTier"].items():
        lines.append(f"| {tier} | {agg['runs']} | {agg['passRate']} | {agg['medianScore']} | {agg['medianWallSeconds']} | {agg['medianFirstTextSeconds']} |")
    lines += [
        "",
        "## By model",
        "",
        "| Model | Runs | Pass rate | Median score | Median wall | Median first text |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for model, agg in summary["byModel"].items():
        lines.append(f"| `{model}` | {agg['runs']} | {agg['passRate']} | {agg['medianScore']} | {agg['medianWallSeconds']} | {agg['medianFirstTextSeconds']} |")
    lines += [
        "",
        "## By challenge",
        "",
        "| Challenge | Runs | Pass rate | Median score | Median wall | Median first text |",
        "|---|---:|---:|---:|---:|---:|",
    ]
    for challenge, agg in summary["byChallenge"].items():
        lines.append(f"| {challenge} | {agg['runs']} | {agg['passRate']} | {agg['medianScore']} | {agg['medianWallSeconds']} | {agg['medianFirstTextSeconds']} |")
    path.write_text("\n".join(lines) + "\n")


def _row(agg: dict) -> str:
    return f"runs={agg['runs']}, passRate={agg['passRate']}, medianScore={agg['medianScore']}, medianWallSeconds={agg['medianWallSeconds']}, medianFirstTextSeconds={agg['medianFirstTextSeconds']}"


def read_history(path: Path, limit: int) -> list[dict]:
    if not path.exists():
        return []
    lines = path.read_text().splitlines()
    values = [json.loads(line) for line in lines if line.strip()]
    return values[-limit:]


def format_trend(history: list[dict]) -> str:
    if not history:
        return "No model-bench history found. Run the benchmark first."
    lines = [
        "# model-bench trend",
        "",
        "| Run | Total pass rate | Total score | Total wall |",
        "|---|---:|---:|---:|",
    ]
    for item in history:
        totals = item.get("totals", {})
        lines.append(
            f"| {item.get('runId')} | {totals.get('passRate')} | {totals.get('medianScore')} | {totals.get('medianWallSeconds')} |"
        )
    return "\n".join(lines)
