from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from .config import load_toml

_FIXTURE_RE = re.compile(r"\{\{fixture:([^}]+)\}\}")


@dataclass(frozen=True)
class Challenge:
    path: Path
    challenge_id: str
    tier: str
    agent: str
    description: str
    runs: int
    timeout_seconds: int
    thinking: str | None
    tools: str | None
    source: dict | None
    prompt: str
    verifier: dict


def _substitute_fixtures(text: str, fixture_root: Path) -> str:
    def replace(match: re.Match[str]) -> str:
        rel = match.group(1).strip()
        path = (fixture_root / rel).resolve()
        try:
            path.relative_to(fixture_root.resolve())
        except ValueError as exc:
            raise ValueError(f"fixture path escapes fixture root: {rel}") from exc
        return path.read_text()

    return _FIXTURE_RE.sub(replace, text)


def render_prompt(challenge: Challenge, cwd: Path) -> str:
    return challenge.prompt.replace("{{source_dir}}", str(cwd))


def load_challenge(path: Path, fixture_root: Path) -> Challenge:
    doc = load_toml(path)
    meta = doc["challenge"]
    prompt_doc = doc["prompt"]
    prompt = _substitute_fixtures(prompt_doc["text"], fixture_root)
    return Challenge(
        path=path,
        challenge_id=meta["id"],
        tier=meta["tier"],
        agent=meta["agent"],
        description=meta.get("description", ""),
        runs=int(meta.get("runs", 1)),
        timeout_seconds=int(meta.get("timeoutSeconds", 180)),
        thinking=meta.get("thinking"),
        tools=meta.get("tools"),
        source=doc.get("source"),
        prompt=prompt,
        verifier=doc.get("verifier", {"type": "regex"}),
    )


def discover_challenges(challenges_dir: Path, fixture_root: Path) -> list[Challenge]:
    paths = sorted(challenges_dir.glob("**/*.toml"))
    challenges: list[Challenge] = []
    seen: set[str] = set()
    for path in paths:
        try:
            challenge = load_challenge(path, fixture_root)
        except Exception as exc:
            raise ValueError(f"failed to load challenge {path}: {exc}") from exc
        if challenge.challenge_id in seen:
            raise ValueError(f"duplicate challenge id {challenge.challenge_id!r} in {path}")
        seen.add(challenge.challenge_id)
        if challenge.runs <= 0:
            raise ValueError(f"challenge {challenge.challenge_id!r} must have runs > 0")
        if challenge.timeout_seconds <= 0:
            raise ValueError(f"challenge {challenge.challenge_id!r} must have timeoutSeconds > 0")
        challenges.append(challenge)
    return challenges
