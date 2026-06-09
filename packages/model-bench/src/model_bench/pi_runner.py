from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import threading
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
        "--",
        prompt,
    ]
    resolved_pi = shutil.which(pi_bin) if os.sep not in pi_bin else pi_bin
    if not resolved_pi or not os.access(resolved_pi, os.X_OK):
        raise FileNotFoundError(f"Pi binary is not executable or not found: {pi_bin}")
    cmd[0] = resolved_pi
    env = os.environ.copy()
    env.setdefault("PI_SKIP_VERSION_CHECK", "1")
    start = time.monotonic()
    stderr_file = tempfile.TemporaryFile(mode="w+t")
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=stderr_file,
        bufsize=1,
    )

    timed_out = False

    def kill_for_timeout() -> None:
        nonlocal timed_out
        timed_out = True
        proc.kill()

    timer = threading.Timer(timeout_seconds, kill_for_timeout)
    timer.start()

    event_count = 0
    first_text_seconds: float | None = None
    final_text = ""
    deltas: list[str] = []

    def handle_line(line: str) -> None:
        nonlocal event_count, first_text_seconds, final_text
        if not line.strip():
            return
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            return
        event_count += 1
        if event.get("type") == "message_update":
            assistant_event = event.get("assistantMessageEvent", {})
            if assistant_event.get("type") == "text_delta":
                delta = assistant_event.get("delta")
                if isinstance(delta, str) and delta:
                    if first_text_seconds is None:
                        first_text_seconds = time.monotonic() - start
                    deltas.append(delta)
        if event.get("type") in {"message_end", "turn_end"}:
            text = _extract_text_from_message(event.get("message", {}))
            if text:
                final_text = text

    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            handle_line(line)
        proc.wait(timeout=5)
    finally:
        timer.cancel()
        if proc.poll() is None:
            proc.kill()
            proc.wait(timeout=5)

    wall = time.monotonic() - start
    stderr_file.seek(0)
    stderr = stderr_file.read()
    stderr_file.close()
    if timed_out:
        raise subprocess.TimeoutExpired(cmd, timeout_seconds)
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
