#!/usr/bin/env python3
"""Create a human-approved sudo workflow request for agent handoff."""

from __future__ import annotations

import argparse
import getpass
import json
import os
import secrets
import shlex
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def state_dir() -> Path:
    explicit = os.environ.get("AGENT_SUDO_STATE_DIR")
    if explicit:
        return Path(explicit).expanduser()
    base = os.environ.get("XDG_STATE_HOME")
    if not base:
        base = str(Path.home() / ".local" / "state")
    return Path(base) / "nix-config" / "sudo-requests"


def now_iso() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def git_metadata(cwd: Path) -> dict[str, str | None]:
    def run_git(args: list[str]) -> str | None:
        try:
            result = subprocess.run(
                ["git", *args],
                cwd=cwd,
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
            )
        except FileNotFoundError:
            return None
        if result.returncode != 0:
            return None
        return result.stdout.strip()

    root = run_git(["rev-parse", "--show-toplevel"])
    if root is None:
        return {"root": None, "head": None, "branch": None, "status_short": None}
    return {
        "root": root,
        "head": run_git(["rev-parse", "HEAD"]),
        "branch": run_git(["branch", "--show-current"]),
        "status_short": run_git(["status", "--short"]),
    }


def write_json_0600(path: Path, payload: dict[str, Any]) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    fd = os.open(path, flags, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
    except Exception:
        try:
            path.unlink()
        except FileNotFoundError:
            pass
        raise


def open_terminal(approve_command: str, request_id: str, cwd: Path) -> None:
    terminal_cmd = f"cd {shlex.quote(str(cwd))} && {shlex.quote(approve_command)} {shlex.quote(request_id)}"
    try:
        subprocess.run(
            [
                "osascript",
                "-e",
                f'tell application "Terminal" to do script {json.dumps(terminal_cmd)}',
                "-e",
                'tell application "Terminal" to activate',
            ],
            check=True,
        )
    except FileNotFoundError:
        print("agent-sudo-request: osascript not found; cannot open Terminal.app", file=sys.stderr)
    except subprocess.CalledProcessError as exc:
        print(f"agent-sudo-request: failed to open Terminal.app: {exc}", file=sys.stderr)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create an auditable request for a human-approved sudo workflow.",
    )
    parser.add_argument("--reason", help="Short reason shown during approval.")
    parser.add_argument(
        "--cwd",
        default=os.getcwd(),
        help="Working directory to record and use during approval. Defaults to current directory.",
    )
    parser.add_argument(
        "--open-terminal",
        action="store_true",
        help="Open Terminal.app with the approval command after creating the request.",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Command argv to run after human approval. Use -- before the command.",
    )
    args = parser.parse_args()
    if args.command and args.command[0] == "--":
        args.command = args.command[1:]
    if not args.command:
        parser.error("missing command; usage: agent-sudo-request [opts] -- COMMAND [ARGS...]")
    return args


def main() -> int:
    args = parse_args()
    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        print(f"agent-sudo-request: cwd is not a directory: {cwd}", file=sys.stderr)
        return 2

    requests_dir = state_dir()
    requests_dir.mkdir(parents=True, exist_ok=True)
    os.chmod(requests_dir, stat.S_IRWXU)

    request_id = f"{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{secrets.token_hex(4)}"
    request_path = requests_dir / f"{request_id}.json"
    approve_command = os.environ.get("AGENT_SUDO_APPROVE_COMMAND", "agent-sudo-approve")

    payload: dict[str, Any] = {
        "version": 1,
        "id": request_id,
        "created_at": now_iso(),
        "user": getpass.getuser(),
        "uid": os.getuid(),
        "cwd": str(cwd),
        "command": args.command,
        "command_display": shlex.join(args.command),
        "reason": args.reason,
        "approve_command": approve_command,
        "git": git_metadata(cwd),
    }
    write_json_0600(request_path, payload)

    approve_invocation = f"{approve_command} {shlex.quote(request_id)}"
    print(f"Created sudo workflow request: {request_id}")
    print(f"Request file: {request_path}")
    if args.reason:
        print(f"Reason: {args.reason}")
    print(f"CWD: {cwd}")
    print(f"Command: {payload['command_display']}")
    print("Approve from your terminal with:")
    print(f"  {approve_invocation}")

    if args.open_terminal:
        open_terminal(approve_command, request_id, cwd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
