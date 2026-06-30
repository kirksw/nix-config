#!/usr/bin/env python3
"""
Thread OS session-start hook.

Resolves which thread the current project belongs to, then enriches the
session JSON with thread context: open blockers, recent decisions, and the
last session's incomplete items. Also writes a lightweight THREAD_CONTEXT.md
into the workspace for human/agent discoverability.

Env vars (set by the Nix hook):
  THREAD_OS_SESSION_FILE — path to the session JSON just written by session-start
  THREAD_OS_PERSONAL_REPO — override personal repo path
  THREAD_OS_WORK_REPO     — override work repo path
  NAX_PROFILE             — profile name for scope detection

Exit codes: 0 always (never crashes the session wrapper).
"""

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Utilities (duplicated from session-thread-sync.py — these are standalone Nix-inlined scripts)
# ---------------------------------------------------------------------------

def today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def slugify(value):
    value = (value or "").strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "session"

def load_json(path):
    try:
        if path and Path(path).exists() and Path(path).stat().st_size > 0:
            return json.loads(Path(path).read_text())
    except Exception:
        pass
    return {}

def read_jsonl(path):
    records = []
    p = Path(path)
    if not p.exists():
        return records
    for line in p.read_text().split("\n"):
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except Exception:
            pass
    return records

def dedup_by_id(records):
    seen = {}
    order = []
    for r in records:
        rid = r.get("id") or r.get("slug") or ""
        if rid not in seen:
            order.append(rid)
        seen[rid] = r
    return [seen[rid] for rid in order if rid in seen]


# ---------------------------------------------------------------------------
# Scope and repo resolution (duplicated from session-thread-sync.py)
# ---------------------------------------------------------------------------

def resolve_repo_and_workspace(repo):
    workspace = repo / "workspace"
    if workspace.exists():
        return repo, workspace

    main_repo = repo / "main"
    main_workspace = main_repo / "workspace"
    if main_workspace.exists():
        return main_repo, main_workspace

    return repo, workspace


def resolve_scope_and_repo():
    personal_repo = Path(os.environ.get(
        "THREAD_OS_PERSONAL_REPO",
        str(Path.home() / "git/github.com/kirksw/lifeOS"),
    ))
    work_repo = Path(os.environ.get(
        "THREAD_OS_WORK_REPO",
        str(Path.home() / "git/github.com/kirksw/lunarOS"),
    ))

    profile = os.environ.get("NAX_PROFILE", "")
    explicit = os.environ.get("THREAD_OS_SCOPE", "").lower()

    if explicit in ("personal", "lunar"):
        scope = explicit
    elif profile.startswith("personal"):
        scope = "personal"
    elif profile.startswith("work"):
        scope = "lunar"
    else:
        return None, None, None

    repo = personal_repo if scope == "personal" else work_repo
    if not repo.exists():
        return None, None, None

    repo, workspace = resolve_repo_and_workspace(repo)
    return scope, repo, workspace


# ---------------------------------------------------------------------------
# Thread resolution (duplicated from session-thread-sync.py)
# ---------------------------------------------------------------------------

def extract_repo_id(project_path):
    if not project_path:
        return None
    parts = Path(project_path).parts
    for i, part in enumerate(parts):
        if part in ("github.com", "gitlab.com", "bitbucket.org") and i + 2 < len(parts):
            return "/".join(parts[i:i + 3])
    return None

def normalize_thread_map(thread_map):
    paths = {}
    repos = {}
    terms = {}
    schema_ver = thread_map.get("schema_version", 1)

    for key, val in thread_map.get("paths", {}).items():
        slug = val.get("default") if isinstance(val, dict) else val
        if isinstance(slug, str):
            paths[key] = slug

    for key, val in thread_map.get("repos", {}).items():
        if isinstance(val, dict):
            slug = val.get("default")
        elif isinstance(val, list):
            slug = val[0] if val else None
        else:
            slug = val
        if isinstance(slug, str):
            repos[key] = slug

    for key, val in thread_map.get("terms", {}).items():
        if not isinstance(val, list):
            continue
        if schema_ver >= 2:
            for term in val:
                terms[term.lower()] = key
        else:
            for thread_slug in val:
                terms[key.lower()] = thread_slug

    return paths, repos, terms

def resolve_thread(workspace, project_path):
    """Resolve thread from project path alone (no summary at session start)."""
    thread_map = load_json(workspace / ".lifeos" / "index" / "thread-map.json")

    threads_dir = workspace / "threads"
    known_slugs = set()
    if threads_dir.is_dir():
        for child in threads_dir.iterdir():
            if child.is_dir() and not child.name.startswith("."):
                known_slugs.add(child.name)

    threads_jsonl = read_jsonl(workspace / ".lifeos" / "db" / "threads.jsonl")
    for rec in threads_jsonl:
        slug = rec.get("slug") or rec.get("id", "").replace("thread:", "")
        if slug:
            known_slugs.add(slug)

    if thread_map:
        paths_map, repos_map, terms_map = normalize_thread_map(thread_map)

        if project_path in paths_map:
            return paths_map[project_path], "path"

        for mapped_path, slug in paths_map.items():
            if mapped_path in project_path or project_path in mapped_path:
                return slug, "path"

        repo_id = extract_repo_id(project_path)
        if repo_id and repo_id in repos_map:
            return repos_map[repo_id], "repo"
        for mapped_repo, slug in repos_map.items():
            if mapped_repo and mapped_repo in project_path:
                return slug, "repo"

    project_slug = slugify(Path(project_path).name) if project_path else ""
    if project_slug and project_slug in known_slugs:
        return project_slug, "slug"

    return None, "none"


# ---------------------------------------------------------------------------
# Context gathering
# ---------------------------------------------------------------------------

def gather_context(db, thread_slug, project_path=""):
    """
    Gather thread context for session-start injection.
    Returns a dict with open_blockers, recent_decisions, and last_session_incomplete.
    """
    context = {
        "thread": thread_slug,
        "open_blockers": [],
        "recent_decisions": [],
        "last_session_incomplete": [],
        "last_session_summary": "",
    }

    if not thread_slug:
        # Inbox mode: gather any past inbox activity for this project
        project_slug = slugify(Path(project_path).name) if project_path else ""
        return gather_inbox_context(db, project_slug)

    thread_id = f"thread:{thread_slug}"

    # Open blockers for this thread
    blockers = dedup_by_id(read_jsonl(db / "blockers.jsonl"))
    context["open_blockers"] = [
        b.get("text", "?") for b in blockers
        if (b.get("threadId") == thread_id or b.get("thread") == thread_slug)
        and b.get("status") != "resolved"
    ]

    # Recent decisions for this thread (last 5)
    decisions = dedup_by_id(read_jsonl(db / "decisions.jsonl"))
    thread_decisions = [
        d for d in decisions
        if d.get("thread") == thread_slug or d.get("threadId") == thread_id
    ]
    context["recent_decisions"] = [
        d.get("title") or d.get("text", "?")
        for d in thread_decisions[-5:]
    ]

    # Last session's incomplete items and summary
    sessions = read_jsonl(db / "sessions.jsonl")
    thread_sessions = [
        s for s in sessions
        if s.get("thread") == thread_slug
    ]
    if thread_sessions:
        last = thread_sessions[-1]
        context["last_session_incomplete"] = last.get("incomplete", [])
        context["last_session_summary"] = last.get("summary", "")

    return context


def gather_inbox_context(db, project_slug):
    """Gather inbox activity for a project when no thread is matched."""
    from datetime import timedelta
    cutoff_dt = datetime.strptime(today(), "%Y-%m-%d") - timedelta(days=14)
    cutoff_str = cutoff_dt.strftime("%Y-%m-%d")

    context = {
        "thread": None,
        "open_blockers": [],
        "recent_decisions": [],
        "last_session_incomplete": [],
        "last_session_summary": "",
        "inbox_count": 0,
        "inbox_suggestion": "",
    }

    sessions = read_jsonl(db / "sessions.jsonl")
    project_sessions = [
        s for s in sessions
        if s.get("thread") == "__inbox__"
        and s.get("project_slug") == project_slug
        and s.get("date", "") >= cutoff_str
    ]

    context["inbox_count"] = len(project_sessions)
    if len(project_sessions) >= 2:
        context["inbox_suggestion"] = (
            f"{len(project_sessions)} unclassified sessions for `{project_slug}` in the last 14 days. "
            "Consider creating a thread: `/thread-os new-thread \"<title>\" --kind <kind>`"
        )

    if project_sessions:
        last = project_sessions[-1]
        context["last_session_incomplete"] = last.get("incomplete", [])
        context["last_session_summary"] = last.get("summary", "")

    return context


def write_context_to_session_json(session_file, thread_slug, match_method, context):
    """Enrich the session JSON with thread context."""
    try:
        data = load_json(session_file)
        if not data:
            return

        data["threadContext"] = {
            "thread": thread_slug,
            "matchMethod": match_method,
            "openBlockers": context.get("open_blockers", []),
            "recentDecisions": context.get("recent_decisions", []),
            "lastSessionIncomplete": context.get("last_session_incomplete", []),
            "lastSessionSummary": context.get("last_session_summary", ""),
            "inboxCount": context.get("inbox_count", 0),
            "inboxSuggestion": context.get("inbox_suggestion", ""),
        }

        Path(session_file).write_text(json.dumps(data, indent=2) + "\n")
    except Exception:
        pass  # non-fatal


def write_context_md(workspace, scope, project_path, thread_slug, match_method, context):
    """Write a human-readable THREAD_CONTEXT.md in the workspace."""
    lines = [
        f"<!-- Generated by thread-os session-start hook. Do not edit — will be overwritten. -->",
        f"# Thread context: {thread_slug or 'unresolved'}",
        "",
        f"- Project: `{project_path or 'unknown'}`",
        f"- Match method: `{match_method}`",
        f"- Scope: `{scope}`",
        f"- Date: {today()}",
        "",
    ]

    if not thread_slug:
        lines.extend([
            "## Status",
            "",
            "No thread matched this project. Work will be routed to inbox.",
            "",
        ])
        inbox_count = context.get("inbox_count", 0)
        if inbox_count:
            lines.extend([
                f"## Inbox history ({inbox_count} sessions in last 14 days)",
                "",
            ])
            suggestion = context.get("inbox_suggestion", "")
            if suggestion:
                lines.append(f"> {suggestion}")
                lines.append("")
        else:
            lines.extend([
                "## Inbox history",
                "",
                "_No previous unclassified sessions for this project._",
                "",
            ])
    else:
        blockers = context.get("open_blockers", [])
        decisions = context.get("recent_decisions", [])
        incomplete = context.get("last_session_incomplete", [])
        summary = context.get("last_session_summary", "")

        lines.extend(["## Open blockers", ""])
        if blockers:
            for b in blockers:
                lines.append(f"- {b}")
        else:
            lines.append("_None._")
        lines.append("")

        lines.extend(["## Recent decisions", ""])
        if decisions:
            for d in decisions:
                lines.append(f"- {d}")
        else:
            lines.append("_None._")
        lines.append("")

        lines.extend(["## Last session incomplete", ""])
        if incomplete:
            for item in incomplete:
                lines.append(f"- {item}")
        else:
            lines.append("_Nothing incomplete._")
        lines.append("")

        if summary:
            lines.extend(["## Last session summary", "", summary, ""])

    context_path = workspace / "THREAD_CONTEXT.md"
    context_path.write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    session_file = Path(os.environ.get("THREAD_OS_SESSION_FILE", ""))
    if not session_file.exists():
        sys.exit(0)

    session = load_json(session_file)
    if not session:
        sys.exit(0)

    scope, repo, workspace = resolve_scope_and_repo()
    if not scope or repo is None or workspace is None:
        sys.exit(0)

    workspace.mkdir(parents=True, exist_ok=True)
    db = workspace / ".lifeos" / "db"

    project_path = session.get("project") or os.environ.get("PWD", "")

    # Resolve thread from project path
    thread_slug, match_method = resolve_thread(workspace, project_path)

    # Gather context
    context = gather_context(db, thread_slug, project_path)

    # Enrich session JSON
    write_context_to_session_json(session_file, thread_slug, match_method, context)

    # Write human-readable context file
    write_context_md(workspace, scope, project_path, thread_slug, match_method, context)

    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"thread-os context injection error: {e}", file=sys.stderr)
        sys.exit(0)
