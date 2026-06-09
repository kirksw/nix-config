from __future__ import annotations

import json
import os
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PiResult:
    output: str
    events: int
    wall_seconds: float
    first_text_seconds: float | None
    returncode: int
    stderr: str


def _extract_text_from_message(message: dict) -> str:
    content = message.get("content", [])
    if isinstance(content, str):
        return content
    chunks: list[str] = []
    if isinstance(content, list):
        for item in content:
            if isinstance(item, str):
                chunks.append(item)
            elif isinstance(item, dict):
                text = item.get("text") or item.get("content")
                if isinstance(text, str):
                    chunks.append(text)
    return "".join(chunks)


def run_pi(
    *,
    pi_bin: str,
    model: str,
    thinking: str,
    prompt: str,
    cwd: Path,
    timeout_seconds: int,
) -> PiResult:
    cmd = [
        pi_bin,
        "--mode",
        "json",
        "--no-session",
        "--no-tools",
        "--no-context-files",
        "--no-prompt-templates",
        "--no-skills",
        "--no-extensions",
        "--model",
        model,
        "--thinking",
        thinking,
        prompt,
    ]
    env = os.environ.copy()
    env.setdefault("PI_SKIP_VERSION_CHECK", "1")
    start = time.monotonic()
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=1,
    )

    event_count = 0
    first_text_seconds: float | None = None
    final_text = ""
    deltas: list[str] = []

    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            if time.monotonic() - start > timeout_seconds:
                proc.kill()
                raise subprocess.TimeoutExpired(cmd, timeout_seconds)
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            event_count += 1
            if event.get("type") == "message_update":
                assistant_event = event.get("assistantMessageEvent", {})
                if assistant_event.get("type") == "text_delta":
                    delta = assistant_event.get("delta")
                    if isinstance(delta, str) and delta:
                        if first_text_seconds is None:
                            first_text_seconds = time.monotonic() - start
                        deltas.append(delta)
            if event.get("type") == "message_end":
                text = _extract_text_from_message(event.get("message", {}))
                if text:
                    final_text = text
            if event.get("type") == "turn_end":
                text = _extract_text_from_message(event.get("message", {}))
                if text:
                    final_text = text
    finally:
        stdout_tail, stderr = proc.communicate(timeout=5)
        for line in stdout_tail.splitlines():
            if not line.strip():
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            event_count += 1
            if event.get("type") in {"message_end", "turn_end"}:
                text = _extract_text_from_message(event.get("message", {}))
                if text:
                    final_text = text

    wall = time.monotonic() - start
    if not final_text and deltas:
        final_text = "".join(deltas)

    return PiResult(
        output=final_text.strip(),
        events=event_count,
        wall_seconds=wall,
        first_text_seconds=first_text_seconds,
        returncode=proc.returncode,
        stderr=stderr.strip(),
    )
