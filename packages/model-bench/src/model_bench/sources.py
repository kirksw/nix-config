from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
from pathlib import Path


def default_repo_cache_dir() -> Path:
    base = os.environ.get("XDG_CACHE_HOME")
    if base:
        return Path(base) / "model-bench" / "repos"
    return Path.home() / ".cache" / "model-bench" / "repos"


def materialize_source(source: dict | None, cache_root: Path) -> Path | None:
    if not source:
        return None
    git_source = source.get("git")
    if not git_source:
        raise ValueError(f"unsupported source config: {source}")
    return _materialize_git(git_source, cache_root)


def _materialize_git(git_source: dict, cache_root: Path) -> Path:
    url = git_source["url"]
    rev = git_source.get("rev") or git_source.get("ref") or "HEAD"
    subdir = git_source.get("path", ".")
    git_bin = shutil.which("git")
    if not git_bin:
        raise FileNotFoundError("git is required for git-backed model-bench challenges")

    key = hashlib.sha256(f"{url}\0{rev}".encode()).hexdigest()[:16]
    repo_dir = cache_root / key / "repo"
    repo_dir.parent.mkdir(parents=True, exist_ok=True)

    if not (repo_dir / ".git").exists():
        subprocess.run(
            [git_bin, "clone", "--filter=blob:none", "--no-checkout", url, str(repo_dir)],
            check=True,
            text=True,
            capture_output=True,
            timeout=600,
        )

    subprocess.run(
        [git_bin, "-C", str(repo_dir), "fetch", "--depth", "1", "origin", rev],
        check=True,
        text=True,
        capture_output=True,
        timeout=600,
    )
    subprocess.run(
        [git_bin, "-C", str(repo_dir), "checkout", "--force", "FETCH_HEAD"],
        check=True,
        text=True,
        capture_output=True,
        timeout=120,
    )
    subprocess.run(
        [git_bin, "-C", str(repo_dir), "clean", "-fdx"],
        check=True,
        text=True,
        capture_output=True,
        timeout=120,
    )

    cwd = (repo_dir / subdir).resolve()
    try:
        cwd.relative_to(repo_dir.resolve())
    except ValueError as exc:
        raise ValueError(f"git source path escapes repository: {subdir}") from exc
    if not cwd.exists():
        raise FileNotFoundError(f"git source path does not exist: {cwd}")
    return cwd
