from __future__ import annotations

import os
import tomllib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class BenchConfig:
    tiers: dict[str, str]
    thinking: dict[str, str]


def data_dir() -> Path:
    return Path(os.environ.get("MODEL_BENCH_DATA_DIR", Path(__file__).resolve().parents[2]))


def default_results_dir() -> Path:
    base = os.environ.get("XDG_DATA_HOME")
    if base:
        return Path(base) / "model-bench" / "results"
    return Path.home() / ".local" / "share" / "model-bench" / "results"


def load_toml(path: Path) -> dict:
    with path.open("rb") as fh:
        return tomllib.load(fh)


def parse_model_overrides(raw: str | None) -> dict[str, str]:
    if not raw:
        return {}
    result: dict[str, str] = {}
    for chunk in raw.split(","):
        chunk = chunk.strip()
        if not chunk:
            continue
        if "=" not in chunk:
            raise ValueError(f"invalid --models entry {chunk!r}; expected tier=model")
        tier, model = chunk.split("=", 1)
        tier = tier.strip()
        model = model.strip()
        if not tier or not model:
            raise ValueError(f"invalid --models entry {chunk!r}; expected tier=model")
        result[tier] = model
    return result


def parse_model_list(raw: str | None) -> list[str]:
    if not raw:
        return []
    models = [chunk.strip() for chunk in raw.split(",") if chunk.strip()]
    if not models:
        raise ValueError("--compare-models was provided but no models were parsed")
    return models


def load_config(path: Path, cli_models: dict[str, str] | None = None) -> BenchConfig:
    doc = load_toml(path)
    tiers = dict(doc.get("tiers", {}))
    thinking = dict(doc.get("thinking", {}))
    tiers.update(cli_models or {})
    return BenchConfig(tiers=tiers, thinking=thinking)


def resolve_model(config: BenchConfig, tier: str) -> str:
    try:
        return config.tiers[tier]
    except KeyError as exc:
        known = ", ".join(sorted(config.tiers)) or "<none>"
        raise KeyError(f"no model configured for tier {tier!r}; configured tiers: {known}") from exc


def resolve_thinking(config: BenchConfig, tier: str, challenge_thinking: str | None = None) -> str:
    return challenge_thinking or config.thinking.get(tier, "high")
