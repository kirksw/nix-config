from __future__ import annotations

import json
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from .pi_runner import run_pi


@dataclass(frozen=True)
class Verification:
    passed: bool
    score: float
    details: dict


def _regex_verify(output: str, spec: dict) -> Verification:
    required = list(spec.get("requiredRegex", []))
    forbidden = list(spec.get("forbiddenRegex", []))
    flags = re.IGNORECASE | re.MULTILINE | re.DOTALL

    matched: list[str] = []
    missed: list[str] = []
    for pattern in required:
        if re.search(pattern, output, flags):
            matched.append(pattern)
        else:
            missed.append(pattern)
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
    forbidden_code = list(spec.get("forbiddenCodeRegex", []))
    flags = re.IGNORECASE | re.MULTILINE | re.DOTALL
    code_hits = [pattern for pattern in forbidden_code if re.search(pattern, code, flags)]
    if code_hits:
        return Verification(
            passed=False,
            score=0.0,
            details={"error": "generated code matched forbiddenCodeRegex", "forbiddenCodeHits": code_hits},
        )
    test_rel = spec["testFile"]
    test_path = fixture_root / test_rel
    with tempfile.TemporaryDirectory(prefix="model-bench-test-") as tmp:
        tmp_path = Path(tmp)
        (tmp_path / "solution.py").write_text(code + "\n")
        (tmp_path / "test_solution.py").write_text(test_path.read_text())
        proc = subprocess.run(
            ["python3", "-I", "-m", "unittest", "-v", "test_solution.py"],
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


def _extract_json_object(text: str) -> dict:
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, re.IGNORECASE | re.DOTALL)
    if fenced:
        return json.loads(fenced.group(1))
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("verifier agent did not return a JSON object")
    return json.loads(text[start : end + 1])


def _agent_binary_verify(
    output: str,
    spec: dict,
    *,
    cwd: Path,
    pi_bin: str,
    default_model: str,
    default_thinking: str,
    default_tools: str,
) -> Verification:
    criteria = spec.get("criteria", [])
    if not criteria:
        raise ValueError("agent-binary verifier requires at least one [[verifier.criteria]] entry")
    model = spec.get("model", default_model)
    thinking = spec.get("thinking", default_thinking)
    tools = spec.get("tools", default_tools)
    timeout = int(spec.get("timeoutSeconds", 300))
    criteria_json = json.dumps(criteria, indent=2, sort_keys=True)
    prompt = f"""
You are a verifier agent. Evaluate a model's answer against binary assessment criteria.

Rules:
- Use tools to inspect the repository in the current working directory when a criterion asks for repo evidence.
- Each criterion is pass/fail only.
- Do not reward plausible claims without evidence when evidence is needed.
- Keep performance out of the quality score.
- Return only valid JSON. No prose, no markdown.

Required JSON shape:
{{
  "criteria": [
    {{"id": "criterion-id", "passed": true, "reason": "short evidence-based reason"}}
  ]
}}

Criteria:
{criteria_json}

Candidate answer:
{output}
""".strip()
    judge = run_pi(
        pi_bin=pi_bin,
        model=model,
        thinking=thinking,
        prompt=prompt,
        cwd=cwd,
        timeout_seconds=timeout,
        tools=tools,
    )
    data = _extract_json_object(judge.output)
    results = data.get("criteria", [])
    by_id = {item.get("id"): item for item in results if isinstance(item, dict)}
    evaluated = []
    passed_count = 0
    for criterion in criteria:
        criterion_id = criterion["id"]
        item = by_id.get(criterion_id, {})
        passed = bool(item.get("passed", False))
        if passed:
            passed_count += 1
        evaluated.append(
            {
                "id": criterion_id,
                "passed": passed,
                "reason": item.get("reason", "missing verifier result"),
                "question": criterion.get("question", ""),
            }
        )
    score = passed_count / len(criteria)
    min_score = float(spec.get("minScore", 1.0))
    return Verification(
        passed=score >= min_score and judge.returncode == 0,
        score=round(score, 4) if judge.returncode == 0 else 0.0,
        details={
            "minScore": min_score,
            "criteria": evaluated,
            "verifierModel": model,
            "verifierWallSeconds": round(judge.wall_seconds, 4),
            "verifierFirstTextSeconds": None if judge.first_text_seconds is None else round(judge.first_text_seconds, 4),
            "verifierReturncode": judge.returncode,
            "verifierStderr": judge.stderr[-1000:],
        },
    )


def verify(
    output: str,
    spec: dict,
    fixture_root: Path,
    *,
    cwd: Path,
    pi_bin: str,
    verifier_model: str,
    verifier_thinking: str,
    verifier_tools: str,
) -> Verification:
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
    if verifier_type == "agent-binary":
        return _agent_binary_verify(
            output,
            spec,
            cwd=cwd,
            pi_bin=pi_bin,
            default_model=verifier_model,
            default_thinking=verifier_thinking,
            default_tools=verifier_tools,
        )
    raise ValueError(f"unsupported verifier type: {verifier_type}")


def verification_to_json(verification: Verification) -> dict:
    return {
        "passed": verification.passed,
        "score": verification.score,
        "details": json.loads(json.dumps(verification.details, default=str)),
    }
