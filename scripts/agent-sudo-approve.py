#!/usr/bin/env python3
"""Approve and run an agent-created sudo workflow request."""

from __future__ import annotations

import argparse
import getpass
import json
import os
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


def request_path_for(identifier: str) -> Path:
    if Path(identifier).name != identifier:
        raise SystemExit("agent-sudo-approve: request id must not contain path separators")
    name = identifier if identifier.endswith(".json") else f"{identifier}.json"
    base = state_dir().resolve()
    return base / name


def load_request(path: Path) -> dict[str, Any]:
    try:
        lst = path.lstat()
        st = path.stat()
    except FileNotFoundError:
        raise SystemExit(f"agent-sudo-approve: request not found: {path}")
    if stat.S_ISLNK(lst.st_mode):
        raise SystemExit("agent-sudo-approve: refusing symlink request file")
    if not stat.S_ISREG(st.st_mode):
        raise SystemExit("agent-sudo-approve: request is not a regular file")
    if st.st_uid != os.getuid():
        raise SystemExit("agent-sudo-approve: refusing request not owned by current user")
    if st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise SystemExit("agent-sudo-approve: refusing group/world-writable request file")
    with path.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    if payload.get("version") != 1:
        raise SystemExit("agent-sudo-approve: unsupported request version")
    created_at = payload.get("created_at")
    try:
        created = datetime.fromisoformat(str(created_at)).astimezone(timezone.utc)
    except ValueError:
        raise SystemExit("agent-sudo-approve: request has invalid created_at timestamp")
    max_age = int(os.environ.get("AGENT_SUDO_MAX_AGE_SECONDS", str(24 * 60 * 60)))
    age = (datetime.now(timezone.utc) - created).total_seconds()
    if max_age > 0 and age > max_age:
        raise SystemExit(f"agent-sudo-approve: request expired ({age:.0f}s old)")
    command = payload.get("command")
    if not isinstance(command, list) or not command or not all(isinstance(item, str) for item in command):
        raise SystemExit("agent-sudo-approve: request has invalid command argv")
    cwd = payload.get("cwd")
    if not isinstance(cwd, str) or not Path(cwd).is_dir():
        raise SystemExit("agent-sudo-approve: request cwd is missing or no longer exists")
    return payload


def list_requests() -> int:
    requests = sorted(state_dir().glob("*.json"))
    pending = [path for path in requests if not path.name.endswith(".done.json")]
    if not pending:
        print("No sudo workflow requests found.")
        return 0
    for path in pending:
        done = path.with_suffix(".done.json")
        status = "done" if done.exists() else "pending"
        try:
            payload = load_request(path)
            print(f"{payload['id']} [{status}] {payload.get('command_display') or shlex.join(payload['command'])}")
        except SystemExit as exc:
            print(f"{path.name} [invalid] {exc}")
    return 0


def print_request(payload: dict[str, Any], path: Path) -> None:
    git = payload.get("git") or {}
    print("Sudo workflow request")
    print(f"  id:      {payload.get('id')}")
    print(f"  file:    {path}")
    print(f"  created: {payload.get('created_at')}")
    print(f"  user:    {payload.get('user')} (uid {payload.get('uid')})")
    if payload.get("reason"):
        print(f"  reason:  {payload.get('reason')}")
    print(f"  cwd:     {payload.get('cwd')}")
    print(f"  command: {payload.get('command_display') or shlex.join(payload['command'])}")
    if git.get("root"):
        print("  git:")
        print(f"    root:   {git.get('root')}")
        print(f"    branch: {git.get('branch') or '(detached)'}")
        print(f"    head:   {git.get('head')}")
        status = git.get("status_short")
        print("    status:")
        if status:
            for line in str(status).splitlines():
                print(f"      {line}")
        else:
            print("      clean")


def confirm_or_exit(request_id: str) -> None:
    if not sys.stdin.isatty():
        raise SystemExit("agent-sudo-approve: interactive terminal required for approval")
    print()
    print("This will run `sudo -v` in this terminal, then execute the command above.")
    response = input(f"Type the request id to approve ({request_id}): ").strip()
    if response != request_id:
        raise SystemExit("agent-sudo-approve: confirmation did not match; aborting")


def write_done(path: Path, payload: dict[str, Any], exit_code: int) -> None:
    done_path = path.with_suffix(".done.json")
    done_payload = {
        "id": payload.get("id"),
        "request": str(path),
        "completed_at": now_iso(),
        "approved_by": getpass.getuser(),
        "exit_code": exit_code,
    }
    tmp_path = done_path.with_name(f"{done_path.name}.{os.getpid()}.tmp")
    fd = os.open(tmp_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(done_payload, handle, indent=2, sort_keys=True)
            handle.write("\n")
        tmp_path.replace(done_path)
    except Exception:
        try:
            tmp_path.unlink()
        except FileNotFoundError:
            pass
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Approve and run a sudo workflow request.")
    parser.add_argument("request", nargs="?", help="Request id from the sudo request state directory.")
    parser.add_argument("--list", action="store_true", help="List known requests.")
    parser.add_argument("--show", action="store_true", help="Show request details without approving or running it.")
    parser.add_argument(
        "--skip-sudo-auth",
        action="store_true",
        help="Do not run sudo -v before the command. Confirmation is still required.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.skip_sudo_auth and not os.environ.get("_AGENT_SUDO_ALLOW_SKIP_AUTH"):
        raise SystemExit("agent-sudo-approve: --skip-sudo-auth is for tests only")

    if args.list:
        return list_requests()
    if not args.request:
        raise SystemExit("agent-sudo-approve: missing request id; use --list to inspect requests")

    path = request_path_for(args.request)
    payload = load_request(path)
    request_id = str(payload["id"])
    done_path = path.with_suffix(".done.json")
    lock_path = path.with_suffix(".lock")

    print_request(payload, path)
    if args.show:
        return 0
    if done_path.exists():
        raise SystemExit(f"agent-sudo-approve: request already completed: {done_path}")

    confirm_or_exit(request_id)

    try:
        lock_path.mkdir(mode=0o700)
    except FileExistsError:
        raise SystemExit("agent-sudo-approve: request is already being approved")

    exit_code = 1
    try:
        if not args.skip_sudo_auth:
            subprocess.run(["sudo", "-v"], check=True)
        print("Running approved command...")
        result = subprocess.run(payload["command"], cwd=payload["cwd"], check=False)
        exit_code = int(result.returncode)
        return exit_code
    finally:
        write_done(path, payload, exit_code)
        try:
            lock_path.rmdir()
        except OSError:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
