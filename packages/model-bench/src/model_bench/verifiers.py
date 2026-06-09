from __future__ import annotations

import json
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Verification:
    passed: bool
    score: float
    details: dict


def _regex_verify(output: str, spec: dict) -> Verification:
    required = list(spec.get("requiredRegex", []))
    forbidden = list(spec.get("forbiddenRegex", []))
    flags = re.IGNORECASE | re.MULTILINE | re.DOTALL

    matched = [pattern for pattern in required if re.search(pattern, output, flags)]
    missed = [pattern for pattern in required if pattern not in matched]
    forbidden_hits = [pattern for pattern in forbidden if re.search(pattern, output, flags)]

    total = len(required) + len(forbidden)
    good = len(matched) + (len(forbidden) - len(forbidden_hits))
    score = 1.0 if total == 0 else good / total
    min_score = float(spec.get("minScore", 1.0))
    passed = score >= min_score and not forbidden_hits
    return Verification(
        passed=passed,
        score=round(score, 4),
        details={
            "matchedRequired": matched,
            "missedRequired": missed,
            "forbiddenHits": forbidden_hits,
            "minScore": min_score,
        },
    )


def _extract_python(output: str) -> str:
    fence = re.search(r"```(?:python|py)?\s*(.*?)```", output, re.IGNORECASE | re.DOTALL)
    if fence:
        return fence.group(1).strip()
    return output.strip()


def _python_unittest_verify(output: str, spec: dict, fixture_root: Path) -> Verification:
    code = _extract_python(output)
    test_rel = spec["testFile"]
    test_path = fixture_root / test_rel
    with tempfile.TemporaryDirectory(prefix="model-bench-test-") as tmp:
        tmp_path = Path(tmp)
        (tmp_path / "solution.py").write_text(code + "\n")
        (tmp_path / "test_solution.py").write_text(test_path.read_text())
        proc = subprocess.run(
            ["python3", "-m", "unittest", "-v", "test_solution.py"],
            cwd=tmp_path,
            text=True,
            capture_output=True,
            timeout=int(spec.get("timeoutSeconds", 30)),
        )
    passed = proc.returncode == 0
    return Verification(
        passed=passed,
        score=1.0 if passed else 0.0,
        details={
            "returncode": proc.returncode,
            "stdout": proc.stdout[-4000:],
            "stderr": proc.stderr[-4000:],
        },
    )


def verify(output: str, spec: dict, fixture_root: Path) -> Verification:
    verifier_type = spec.get("type", "regex")
    if verifier_type in {
        "regex",
        "structured-findings",
        "review-format",
        "severity-tiers",
        "failure-modes",
        "design-options",
        "decision-call",
    }:
        return _regex_verify(output, spec)
    if verifier_type == "python-unittest":
        return _python_unittest_verify(output, spec, fixture_root)
    raise ValueError(f"unsupported verifier type: {verifier_type}")


def verification_to_json(verification: Verification) -> dict:
    return {
        "passed": verification.passed,
        "score": verification.score,
        "details": json.loads(json.dumps(verification.details, default=str)),
    }
