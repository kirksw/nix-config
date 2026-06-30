#!/usr/bin/env python3
"""
Thread OS session-end hook.

Bridges Pi session activity to the Thread OS JSONL store.
Replaces the inline Python heredoc in session-write.nix.

Env vars (set by the Nix hook):
  THREAD_OS_SESSION_FILE — path to the session JSON written at session-start
  THREAD_OS_EVENT_FILE   — path to the session-end event payload (may be empty)
  THREAD_OS_PERSONAL_REPO — override personal repo path
  THREAD_OS_WORK_REPO     — override work repo path
  NAX_PROFILE             — profile name for scope detection

Exit codes: 0 on success or graceful skip. Never crashes the session wrapper.
"""

import json
import os
import re
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")

def slugify(value):
    value = (value or "").strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
    return value or "session"

def new_id(prefix):
    short = uuid.uuid4().hex[:8]
    ts = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    return f"{prefix}_{ts}_{short}"

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
    for i, line in enumerate(p.read_text().split("\n"), 1):
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except Exception:
            pass  # skip malformed lines
    return records

def append_jsonl(path, record):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a") as f:
        f.write(json.dumps(record) + "\n")

def write_jsonl(path, records):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w") as f:
        for r in records:
            f.write(json.dumps(r) + "\n")

def dedup_by_id(records):
    """Keep the last record for each id, preserving order of first occurrence."""
    seen = {}
    order = []
    for r in records:
        rid = r.get("id") or r.get("slug") or ""
        if rid not in seen:
            order.append(rid)
        seen[rid] = r
    return [seen[rid] for rid in order if rid in seen]


# ---------------------------------------------------------------------------
# Scope and repo resolution
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
    """Return (scope, repo_path, workspace_path) or (None, None, None) if unresolvable."""
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
# Thread association
# ---------------------------------------------------------------------------

def load_thread_map(workspace):
    return load_json(workspace / ".lifeos" / "index" / "thread-map.json")

def extract_repo_id(project_path):
    """Extract a repo identifier like 'github.com/kirksw/repo' from a path."""
    if not project_path:
        return None
    parts = Path(project_path).parts
    for i, part in enumerate(parts):
        if part in ("github.com", "gitlab.com", "bitbucket.org") and i + 2 < len(parts):
            return "/".join(parts[i:i + 3])
    # Try to match just the last meaningful segments
    return None

def normalize_thread_map(thread_map):
    """
    Normalize v1 and v2 thread-map schemas to:
      paths:  { path_string: slug }
      repos:  { repo_id: slug }
      terms:  { search_term_lower: slug }
    """
    paths = {}
    repos = {}
    terms = {}

    schema_ver = thread_map.get("schema_version", 1)

    # Paths
    for key, val in thread_map.get("paths", {}).items():
        slug = val.get("default") if isinstance(val, dict) else val
        if isinstance(slug, str):
            paths[key] = slug

    # Repos
    for key, val in thread_map.get("repos", {}).items():
        if isinstance(val, dict):
            slug = val.get("default")
        elif isinstance(val, list):
            slug = val[0] if val else None
        else:
            slug = val
        if isinstance(slug, str):
            repos[key] = slug

    # Terms (schema-dependent orientation)
    for key, val in thread_map.get("terms", {}).items():
        if not isinstance(val, list):
            continue
        if schema_ver >= 2:
            # v2: key is thread slug, values are search terms
            thread_slug = key
            for term in val:
                terms[term.lower()] = thread_slug
        else:
            # v1: key is search term, values are thread slugs
            term = key.lower()
            for thread_slug in val:
                terms[term] = thread_slug

    return paths, repos, terms

def resolve_thread(workspace, session, summary_text):
    """
    Determine which thread this session belongs to.
    Returns (slug, match_method, confidence).
    """
    project_path = session.get("project") or ""
    thread_map = load_thread_map(workspace)

    # Known thread slugs from existing directories
    threads_dir = workspace / "threads"
    known_slugs = set()
    if threads_dir.is_dir():
        for child in threads_dir.iterdir():
            if child.is_dir() and not child.name.startswith("."):
                known_slugs.add(child.name)

    # Also check threads.jsonl for slugs
    threads_jsonl = read_jsonl(workspace / ".lifeos" / "db" / "threads.jsonl")
    for rec in threads_jsonl:
        slug = rec.get("slug") or rec.get("id", "").replace("thread:", "")
        if slug:
            known_slugs.add(slug)

    if thread_map:
        paths_map, repos_map, terms_map = normalize_thread_map(thread_map)

        # 1. Exact path match
        if project_path in paths_map:
            slug = paths_map[project_path]
            if slug in known_slugs or True:  # trust the map even if dir doesn't exist yet
                return slug, "path", "high"

        # 1b. Path prefix / substring match
        for mapped_path, slug in paths_map.items():
            if mapped_path in project_path or project_path in mapped_path:
                return slug, "path", "high"

        # 2. Repo match
        repo_id = extract_repo_id(project_path)
        if repo_id and repo_id in repos_map:
            return repos_map[repo_id], "repo", "high"
        for mapped_repo, slug in repos_map.items():
            if mapped_repo and mapped_repo in project_path:
                return slug, "repo", "medium"

        # 3. Term match against summary text
        if summary_text and terms_map:
            search_lower = summary_text.lower()
            scored = {}
            for term, slug in terms_map.items():
                if term and term in search_lower:
                    scored[slug] = scored.get(slug, 0) + len(term)
            if scored:
                best = max(scored, key=lambda k: scored[k])
                return best, "term", "medium"

    # 4. Slug match against thread directories
    project_slug = slugify(Path(project_path).name) if project_path else ""
    if project_slug and project_slug in known_slugs:
        return project_slug, "slug", "medium"

    # 5. No match
    return None, "none", "low"


# ---------------------------------------------------------------------------
# Decision extraction
# ---------------------------------------------------------------------------

DECISION_PATTERNS = [
    # "Decided: ..." or "Decision: ..." at sentence/clause start
    re.compile(r"(?:^|[.!?]\s+)(?:decided|decision)\s*[:\-]\s*(.+)", re.I),
    # "Decided to ..." / "Chose to ..." at sentence/clause start
    re.compile(r"(?:^|[.!?]\s+)(?:decided|chose|settled\s+on|concluded)\s+to\s+(.+)", re.I),
    # "We will use/adopt/switch to ..."
    re.compile(r"(?:^|[.!?]\s+)(?:we\s+will|we'?ll|going\s+to)\s+(?:use|adopt|go\s+with|switch\s+to|implement|build|drop|remove|deprecate)\s+(.+)", re.I),
]

def extract_decisions(summary, accomplished):
    """Extract candidate decisions from text using heuristics."""
    decisions = []
    seen = set()

    lines = []
    if isinstance(accomplished, list):
        lines.extend(str(item) for item in accomplished)
    if summary:
        # Split summary into sentences
        lines.extend(re.split(r"[.!?\n]+", summary))

    for line in lines:
        line = line.strip()
        if len(line) < 10:
            continue
        for pattern in DECISION_PATTERNS:
            m = pattern.search(line)
            if m:
                text = m.group(1).strip().rstrip(".")
                if len(text) >= 10 and text.lower() not in seen:
                    seen.add(text.lower())
                    decisions.append(text)
                    break

    return decisions


# ---------------------------------------------------------------------------
# Blocker extraction
# ---------------------------------------------------------------------------

BLOCKER_PATTERNS = [
    re.compile(r"\b(?:blocked\s+by|blocked\s+on|stuck\s+on|waiting\s+on|depends\s+on|can'?t\s+proceed|cannot\s+proceed|failed\s+to)\b\s*:?\s*(.+)", re.I),
]

def extract_blockers(summary, incomplete):
    """Extract candidate blockers from text using heuristics."""
    blockers = []
    seen = set()

    items = []
    if isinstance(incomplete, list):
        items.extend(str(item) for item in incomplete)
    if summary:
        items.extend(re.split(r"[.!?\n]+", summary))

    for item in items:
        item = item.strip()
        if len(item) < 10:
            continue
        # Direct incomplete items are blockers
        if isinstance(incomplete, list) and item in [str(x) for x in incomplete]:
            if item.lower() not in seen:
                seen.add(item.lower())
                blockers.append(item)
            continue
        # Pattern match
        for pattern in BLOCKER_PATTERNS:
            m = pattern.search(item)
            if m:
                text = m.group(1).strip().rstrip(".")
                if len(text) >= 10 and text.lower() not in seen:
                    seen.add(text.lower())
                    blockers.append(text)
                    break

    return blockers


# ---------------------------------------------------------------------------
# Status inference
# ---------------------------------------------------------------------------

def infer_thread_status(summary, accomplished, incomplete):
    """Infer a status update for the thread based on session content."""
    combined = " ".join(
        [summary or ""] +
        [str(x) for x in (accomplished or [])] +
        [str(x) for x in (incomplete or [])]
    ).lower()

    if any(w in combined for w in ["complete", "finished", "done", "shipped", "merged", "deployed", "resolved"]):
        if not incomplete:
            return "done"
    if any(w in combined for w in ["blocked", "stuck", "waiting", "can't proceed", "cannot proceed"]):
        return "blocked"
    if any(w in combined for w in ["paused", "deprioritized", "parked", "deferred"]):
        return "paused"
    return None  # no change


# ---------------------------------------------------------------------------
# Inbox pseudo-thread
# ---------------------------------------------------------------------------

INBOX_SLUG = "__inbox__"
INBOX_LOOKBACK_DAYS = 14


def detect_inbox_patterns(db):
    """
    Group inbox sessions by project_slug within the lookback window.
    Returns a list of dicts: [{project_slug, count, first_date, last_date, sample_summary}]
    for projects with 2+ sessions.
    """
    sessions = read_jsonl(db / "sessions.jsonl")
    cutoff = today()
    cutoff_dt = datetime.strptime(cutoff, "%Y-%m-%d")
    from datetime import timedelta
    cutoff_dt = cutoff_dt - timedelta(days=INBOX_LOOKBACK_DAYS)
    cutoff_str = cutoff_dt.strftime("%Y-%m-%d")

    # Group inbox sessions by project_slug
    grouped = {}
    for s in sessions:
        if s.get("thread") != INBOX_SLUG:
            continue
        date = s.get("date", "")
        if date < cutoff_str:
            continue
        pslug = s.get("project_slug", "unknown")
        if pslug in ("", "session", "home"):
            continue
        if pslug not in grouped:
            grouped[pslug] = {
                "project_slug": pslug,
                "count": 0,
                "first_date": date,
                "last_date": date,
                "sample_summary": s.get("summary", "")[:120],
            }
        else:
            grouped[pslug]["count"] += 1
            if date < grouped[pslug]["first_date"]:
                grouped[pslug]["first_date"] = date
            if date > grouped[pslug]["last_date"]:
                grouped[pslug]["last_date"] = date

    # Only surface projects with 2+ sessions (first occurrence sets count=0,
    # subsequent ones increment — so threshold 1 means 2+ total sessions)
    patterns = [
        g for g in grouped.values()
        if g["count"] >= 1
    ]
    patterns.sort(key=lambda x: x["count"], reverse=True)
    return patterns


# ---------------------------------------------------------------------------
# Scoring (port of core/scoring.ts)
# ---------------------------------------------------------------------------

def _n(value, fallback):
    """Clamp a value to 0-10, defaulting to fallback if missing/non-numeric."""
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return fallback
    if value != value:  # NaN check
        return fallback
    return max(0, min(10, value))


def score_threads(threads, blockers, metrics, edges):
    """
    Score active threads for focus ranking.
    Port of core/scoring.ts scoreThreads().
    """
    scored = []
    for thread in threads:
        if thread.get("status") == "done":
            continue
        # The inbox pseudo-thread is scored separately, not ranked with real threads
        slug = thread.get("slug") or thread.get("id", "").replace("thread:", "")
        if slug == INBOX_SLUG:
            continue
        thread_id = thread.get("id", "")

        open_blockers = [
            b for b in blockers
            if (b.get("threadId") == thread_id or b.get("thread") == thread.get("slug"))
            and b.get("status") != "resolved"
        ]

        metric_ids = set()
        for e in edges:
            if e.get("from") == thread_id and e.get("relation") in ("contributes_to", "relationship"):
                metric_ids.add(e.get("to", ""))
        linked_metrics = [m for m in metrics if m.get("id") in metric_ids]

        score = (
            _n(thread.get("impact"), 5) * 2
            + _n(thread.get("confidence"), 5)
            + _n(thread.get("urgency"), 5) * 1.5
            + _n(thread.get("salience"), 5)
            + _n(thread.get("manualOverride"), 0)
            - _n(thread.get("effort"), 5)
            - len(open_blockers) * 4
            + len(linked_metrics)
        )

        reasons = [
            f"impact {_n(thread.get('impact'), 5)}",
            f"confidence {_n(thread.get('confidence'), 5)}",
            f"urgency {_n(thread.get('urgency'), 5)}",
            f"effort {_n(thread.get('effort'), 5)}",
            f"salience {_n(thread.get('salience'), 5)}",
        ]
        if open_blockers:
            reasons.append(f"{len(open_blockers)} blocker(s)")
        if linked_metrics:
            reasons.append(f"{len(linked_metrics)} metric link(s)")
        if thread.get("manualOverride"):
            reasons.append(f"manual override {thread['manualOverride']}")

        scored.append({
            "thread": thread,
            "score": score,
            "reasons": reasons,
            "blockers": open_blockers,
            "metrics": linked_metrics,
        })

    scored.sort(key=lambda x: x["score"], reverse=True)
    return scored


def write_focus_md(workspace, db):
    """Regenerate FOCUS.md generated section from current JSONL state."""
    threads = dedup_by_id(read_jsonl(db / "threads.jsonl"))
    blockers = dedup_by_id(read_jsonl(db / "blockers.jsonl"))
    metrics = dedup_by_id(read_jsonl(db / "metrics.jsonl"))
    edges = dedup_by_id(read_jsonl(db / "edges.jsonl"))
    scored = score_threads(threads, blockers, metrics, edges)

    lines = ["Recommended threads:", ""]
    for item in scored[:8]:
        t = item["thread"]
        lines.append(f"## {t.get('title', t.get('slug', 'unknown'))}")
        lines.append("")
        lines.append(f"- Slug: {t.get('slug', '?')}")
        lines.append(f"- Score: {item['score']:.1f}")
        lines.append(f"- Status/stage: {t.get('status', '?')} / {t.get('stage', '?')}")
        lines.append(f"- Reasons: {', '.join(item['reasons'])}")
        if item["blockers"]:
            lines.append(f"- Blockers: {'; '.join(b.get('text', '?') for b in item['blockers'])}")
        if item["metrics"]:
            lines.append(f"- Metrics: {', '.join(m.get('name', '?') for m in item['metrics'])}")
        lines.append("")

    if not scored:
        lines = ["No active threads yet."]

    # --- Inbox review section (14-day lookback) ---
    lines.extend(_inbox_focus_section(db))

    content = "\n".join(lines)
    focus_path = workspace / "FOCUS.md"
    _write_generated_section(focus_path, "# Thread OS Focus\n\n", content)


def _write_generated_section(path, fallback, content):
    """Write or replace a generated section in a markdown file."""
    start_marker = "<!-- lifeos:generated:start -->"
    end_marker = "<!-- lifeos:generated:end -->"
    body = content.rstrip("\n")
    block = f"{start_marker}\n{body}\n{end_marker}"

    if path.exists():
        text = path.read_text()
        pattern = re.compile(
            re.escape(start_marker) + r".*?" + re.escape(end_marker), re.S
        )
        matches = list(pattern.finditer(text))
        if len(matches) == 1:
            text = pattern.sub(block, text, count=1)
        elif len(matches) == 0:
            sep = "\n" if text.endswith("\n") else "\n\n"
            text = text.rstrip("\n") + f"\n\n{block}\n"
        else:
            return  # ambiguous; skip
    else:
        text = f"{fallback}\n{block}\n"

    path.write_text(text)


def _inbox_focus_section(db):
    """Build the inbox review section for FOCUS.md (14-day lookback)."""
    from datetime import timedelta
    cutoff_dt = datetime.strptime(today(), "%Y-%m-%d") - timedelta(days=INBOX_LOOKBACK_DAYS)
    cutoff_str = cutoff_dt.strftime("%Y-%m-%d")

    lines = ["", "---", "", "## Inbox review", ""]
    has_content = False

    # Pattern detection: projects with 2+ inbox sessions
    patterns = detect_inbox_patterns(db)
    if patterns:
        has_content = True
        lines.append("### Consider creating threads")
        lines.append("")
        for p in patterns:
            lines.append(
                f"- `{p['project_slug']}` — {p['count'] + 1} unclassified session(s) "
                f"({p['first_date']} to {p['last_date']})"
            )
            if p.get("sample_summary"):
                lines.append(f"  > {p['sample_summary']}")
        lines.append("")

    # Orphaned decisions from inbox (last 14 days)
    decisions = dedup_by_id(read_jsonl(db / "decisions.jsonl"))
    inbox_decisions = [
        d for d in decisions
        if d.get("thread") == INBOX_SLUG
        and (d.get("created_at", "")[:10] >= cutoff_str)
    ]
    if inbox_decisions:
        has_content = True
        lines.append("### Recent unclassified decisions")
        lines.append("")
        for d in inbox_decisions[:8]:
            lines.append(f"- {d.get('title') or d.get('text', '?')}")
        lines.append("")

    # Orphaned blockers from inbox (last 14 days)
    blockers = dedup_by_id(read_jsonl(db / "blockers.jsonl"))
    inbox_blockers = [
        b for b in blockers
        if b.get("thread") == INBOX_SLUG
        and b.get("status") != "resolved"
        and (b.get("created_at", "")[:10] >= cutoff_str)
    ]
    if inbox_blockers:
        has_content = True
        lines.append("### Open unclassified blockers")
        lines.append("")
        for b in inbox_blockers[:8]:
            lines.append(f"- {b.get('text', '?')}")
        lines.append("")

    if not has_content:
        lines.append("_No unclassified activity in the last 14 days._")
        lines.append("")

    return lines


# ---------------------------------------------------------------------------
# thread-map.json feedback loop
# ---------------------------------------------------------------------------

def update_thread_map(workspace, project_path, thread_slug, match_method):
    """
    When the hook matches via term or slug, record the path/repo in
    thread-map.json so the next session gets a high-confidence path match.
    """
    if not thread_slug or match_method in ("path", "repo", "none", "inbox"):
        return  # already mapped, inbox pseudo-thread, or nothing to learn
    if thread_slug == INBOX_SLUG:
        return

    if not project_path:
        return

    map_path = workspace / ".lifeos" / "index" / "thread-map.json"
    thread_map = load_json(map_path)
    if not thread_map:
        return

    changed = False
    schema_ver = thread_map.get("schema_version", 1)
    repo_id = extract_repo_id(project_path)

    # Add to paths
    paths = thread_map.setdefault("paths", {})
    if isinstance(paths.get(project_path), dict):
        if paths[project_path].get("default") != thread_slug:
            paths[project_path]["default"] = thread_slug
            changed = True
    elif paths.get(project_path) != thread_slug:
        if schema_ver >= 2:
            paths[project_path] = thread_slug
        else:
            paths[project_path] = {"default": thread_slug, "related": []}
        changed = True

    # Add to repos
    if repo_id:
        repos = thread_map.setdefault("repos", {})
        if isinstance(repos.get(repo_id), dict):
            if repos[repo_id].get("default") != thread_slug:
                repos[repo_id]["default"] = thread_slug
                changed = True
        elif isinstance(repos.get(repo_id), list):
            if thread_slug not in repos[repo_id]:
                repos[repo_id].insert(0, thread_slug)
                changed = True
        elif repos.get(repo_id) != thread_slug:
            if schema_ver >= 2:
                repos[repo_id] = [thread_slug]
            else:
                repos[repo_id] = {"default": thread_slug, "related": []}
            changed = True

    if changed:
        thread_map["updated_at"] = now_iso()
        map_path.write_text(json.dumps(thread_map, indent=2) + "\n")


# ---------------------------------------------------------------------------
# Thread scoring parameter inference
# ---------------------------------------------------------------------------

def adjust_thread_scores(records, thread_slug, n_decisions, n_blockers, new_status):
    """
    Adjust scoring parameters on the matched thread based on what happened
    in this session. Operates in-place on the records list (already deduped).
    Returns True if any record was modified.
    """
    if not thread_slug:
        return False

    ts = now_iso()
    modified = False

    for rec in records:
        rec_slug = rec.get("slug") or rec.get("id", "").replace("thread:", "")
        if rec_slug != thread_slug:
            continue

        # Ensure numeric scoring fields exist with defaults
        if "impact" not in rec:
            rec["impact"] = 5
            modified = True
        if "confidence" not in rec:
            rec["confidence"] = 5
            modified = True
        if "urgency" not in rec:
            rec["urgency"] = 5
            modified = True
        if "effort" not in rec:
            rec["effort"] = 5
            modified = True

        # Urgency: new blockers raise it
        if n_blockers > 0:
            old_u = rec.get("urgency", 5)
            rec["urgency"] = min(10, old_u + min(n_blockers, 2))
            if rec["urgency"] != old_u:
                modified = True

        # Confidence: decisions made raise it
        if n_decisions > 0:
            old_c = rec.get("confidence", 5)
            rec["confidence"] = min(10, old_c + min(n_decisions * 0.5, 2))
            if rec["confidence"] != old_c:
                modified = True

        # Salience reinforcement: update last_reinforced if salience is an object,
        # or bump numeric salience slightly.
        sal = rec.get("salience")
        if isinstance(sal, dict):
            if sal.get("last_reinforced") != today():
                sal["last_reinforced"] = today()
                rec["salience"] = sal
                modified = True
        elif isinstance(sal, (int, float)) and not isinstance(sal, bool):
            old_s = sal
            rec["salience"] = min(10, old_s + 0.5)
            if rec["salience"] != old_s:
                modified = True

        # Status-driven adjustments
        if new_status == "blocked":
            old_u = rec.get("urgency", 5)
            rec["urgency"] = min(10, old_u + 1)
            if rec["urgency"] != old_u:
                modified = True
        elif new_status == "done":
            # Completed work lowers impact (it's finished)
            old_i = rec.get("impact", 5)
            rec["impact"] = max(0, old_i - 3)
            if rec["impact"] != old_i:
                modified = True

        break  # only one thread record matches

    return modified


# ---------------------------------------------------------------------------
# Core actions
# ---------------------------------------------------------------------------

def _md_list(items, empty):
    """Render a list as markdown bullets, or the empty placeholder."""
    if not items:
        return empty + "\n"
    return "".join(f"- {item}\n" for item in items)


def write_session_note(workspace, scope, session, event, thread_slug, match_method):
    """Write the session markdown note (preserves existing hook behavior)."""
    project_path = session.get("project") or ""
    project_name = Path(project_path).name if project_path else ""
    project_slug = slugify(project_name)

    # Determine target directory
    if thread_slug and thread_slug != INBOX_SLUG:
        target_dir = workspace / "threads" / thread_slug
        assoc = f"Associated to thread `{thread_slug}` via {match_method} match."
    else:
        # Inbox: route session note to workspace/inbox/
        target_dir = workspace / "inbox"
        if project_slug in ("", "session", "home"):
            assoc = "No clear project path; routed to workspace inbox."
        else:
            assoc = f"No thread matched project `{project_slug}`; routed to inbox."

    sessions_dir = target_dir / "sessions"
    sessions_dir.mkdir(parents=True, exist_ok=True)

    # Build filename
    ended_at = session.get("endedAt") or now_iso()
    date_part = ended_at[:10] if len(ended_at) >= 10 else today()
    time_part = ended_at[11:19].replace(":", "-") if len(ended_at) >= 19 else \
        datetime.now(timezone.utc).strftime("%H-%M-%S")
    session_id = slugify(str(session.get("sessionId") or event.get("sessionId") or "session"))
    file_slug = thread_slug if (thread_slug and thread_slug != INBOX_SLUG) else "inbox"
    session_note = sessions_dir / f"{date_part}-{time_part}-{file_slug}-{session_id}.md"

    # Avoid collision
    if session_note.exists():
        suffix = 1
        while True:
            candidate = session_note.with_name(
                session_note.stem + f"-{suffix}" + session_note.suffix
            )
            if not candidate.exists():
                session_note = candidate
                break
            suffix += 1

    summary = (
        event.get("summary")
        or event.get("sessionSummary")
        or event.get("transcriptSummary")
        or session.get("summary")
        or "Session metadata captured automatically. Review and expand with outcomes, decisions, and next actions."
    )
    accomplished = session.get("accomplished") or event.get("accomplished") or []
    incomplete = session.get("incomplete") or event.get("incomplete") or []
    started = session.get("startedAt") or "unknown"
    duration = session.get("durationSec")
    duration_text = f"{duration} seconds" if isinstance(duration, int) else "unknown"
    branch = session.get("branch") or "unknown"
    commit = session.get("lastCommit") or "unknown"
    profile = session.get("profile") or os.environ.get("NAX_PROFILE", "")

    accomplished_md = _md_list(accomplished, '_No accomplishments captured automatically._')
    incomplete_md = _md_list(incomplete, '_No incomplete items captured automatically._')

    note_content = (
        f"# Session {date_part} {time_part.replace('-', ':')} UTC\n\n"
        "## Metadata\n\n"
        f"- Profile: `{profile}`\n"
        f"- Workspace: `{scope}`\n"
        f"- Project path: `{project_path or 'unknown'}`\n"
        f"- Thread: `{thread_slug or 'inbox'}` (matched via {match_method})\n"
        f"- Branch: `{branch}`\n"
        f"- Commit: `{commit}`\n"
        f"- Started: `{started}`\n"
        f"- Ended: `{ended_at}`\n"
        f"- Duration: {duration_text}\n\n"
        "## Summary\n\n"
        f"{summary}\n\n"
        "## Accomplished\n\n"
        f"{accomplished_md}\n"
        "## Incomplete\n\n"
        f"{incomplete_md}\n\n"
        "## Associativity\n\n"
        f"{assoc}\n\n"
        "## Next actions\n\n"
        "- [ ] Review this generated summary.\n"
        "- [ ] Update project context and tracker manual notes if needed.\n"
    )

    session_note.write_text(note_content)
    return session_note


def update_tracker(workspace, scope):
    """Update TRACKER.md generated section (preserves existing behavior)."""

    def latest_session(project_dir):
        sessions = sorted(
            (project_dir / "sessions").glob("*.md"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        return sessions[0] if sessions else None

    tracker = workspace / "TRACKER.md"
    if not tracker.exists():
        tracker.write_text(
            f"# {scope.title()} Tracker\n\n"
            "<!-- lifeos:generated:start -->\n"
            "_No generated activity yet._\n"
            "<!-- lifeos:generated:end -->\n\n"
            "## Manual notes\n\n"
        )

    project_lines = []
    for child in sorted(workspace.iterdir(), key=lambda p: p.name):
        if not child.is_dir() or child.name in ("inbox", ".lifeos"):
            continue
        latest = latest_session(child)
        session_count = (
            len(list((child / "sessions").glob("*.md")))
            if (child / "sessions").exists()
            else 0
        )
        latest_link = "none"
        if latest:
            latest_link = f"[{latest.name}]({latest.relative_to(workspace).as_posix()})"
        project_lines.append(
            f"- `{child.name}` — {session_count} session(s); latest: {latest_link}"
        )

    inbox_sessions = (
        list((workspace / "inbox" / "sessions").glob("*.md"))
        if (workspace / "inbox" / "sessions").exists()
        else []
    )

    generated = [
        "<!-- lifeos:generated:start -->",
        f"_Last updated: {now_iso()}._",
        "",
        "## Active projects",
        "",
    ]
    generated.extend(project_lines or ["_No project sessions yet._"])
    generated.extend([
        "",
        "## Inbox",
        "",
        f"- {len(inbox_sessions)} unclassified session(s).",
        "<!-- lifeos:generated:end -->",
    ])
    new_block = "\n".join(generated)

    text = tracker.read_text()
    pattern = re.compile(
        r"<!-- lifeos:generated:start -->.*?<!-- lifeos:generated:end -->", re.S
    )
    matches = list(pattern.finditer(text))
    if len(matches) == 1:
        text = pattern.sub(new_block, text, count=1)
    elif len(matches) == 0:
        text = text.rstrip() + "\n\n" + new_block + "\n"
    else:
        return  # ambiguous; leave unchanged

    tracker.write_text(text)


def write_session_record(db, scope, session, event, thread_slug, match_method, session_note_path):
    """Write a structured session record to sessions.jsonl."""
    session_id = session.get("sessionId") or event.get("sessionId") or new_id("session")
    record = {
        "id": f"session:{slugify(str(session_id))}",
        "type": "pi_session",
        "source": "pi",
        "schema_version": 2,
        "scope": scope,
        "date": (session.get("endedAt") or now_iso())[:10],
        "started_at": session.get("startedAt"),
        "ended_at": session.get("endedAt"),
        "duration_sec": session.get("durationSec"),
        "profile": session.get("profile") or os.environ.get("NAX_PROFILE", ""),
        "project_path": session.get("project"),
        "project_slug": slugify(Path(session.get("project") or "").name),
        "branch": session.get("branch"),
        "commit": session.get("lastCommit"),
        "summary": (
            event.get("summary")
            or event.get("sessionSummary")
            or event.get("transcriptSummary")
            or session.get("summary")
            or ""
        ),
        "thread": thread_slug,
        "thread_match_method": match_method,
        "thread_match_confidence": "high" if match_method in ("path", "repo") else "medium" if match_method != "none" else "low",
        "accomplished": session.get("accomplished") or event.get("accomplished") or [],
        "incomplete": session.get("incomplete") or event.get("incomplete") or [],
        "session_note_path": str(session_note_path.relative_to(session_note_path.parents[-3])) if len(session_note_path.parents) >= 3 else str(session_note_path),
        "created_at": now_iso(),
        "updated_at": now_iso(),
    }
    append_jsonl(db / "sessions.jsonl", record)
    return record


def write_decision_records(db, scope, session_id_str, thread_slug, decisions):
    """Write extracted decisions to decisions.jsonl."""
    ts = now_iso()
    written = []
    for i, text in enumerate(decisions):
        record = {
            "id": f"decision:session-{slugify(session_id_str)}-{i+1}",
            "type": "decision",
            "title": text[:200],
            "rationale": "Extracted from Pi session summary at session-end.",
            "confidence": "medium",
            "source": "pi_session",
            "session_id": session_id_str,
            "thread": thread_slug,
            "scope": scope,
            "schema_version": 1,
            "status": "auto-extracted",
            "created_at": ts,
            "updated_at": ts,
        }
        # Include camelCase aliases for TS extension compatibility
        record["text"] = text[:200]
        record["createdAt"] = ts
        record["updatedAt"] = ts
        record["threadId"] = f"thread:{thread_slug}" if thread_slug else None
        append_jsonl(db / "decisions.jsonl", record)
        written.append(record)
    return written


def write_blocker_records(db, scope, session_id_str, thread_slug, blockers):
    """Write extracted blockers to blockers.jsonl."""
    ts = now_iso()
    written = []
    for i, text in enumerate(blockers):
        record = {
            "id": f"blocker:session-{slugify(session_id_str)}-{i+1}",
            "type": "blocker",
            "text": text[:500],
            "status": "open",
            "source": "pi_session",
            "session_id": session_id_str,
            "thread": thread_slug,
            "scope": scope,
            "schema_version": 1,
            "created_at": ts,
            "updated_at": ts,
        }
        # camelCase aliases for TS extension compatibility
        record["threadId"] = f"thread:{thread_slug}" if thread_slug else None
        record["createdAt"] = ts
        record["updatedAt"] = ts
        append_jsonl(db / "blockers.jsonl", record)
        written.append(record)
    return written


def update_thread_record(db, scope, thread_slug, session, new_status=None, n_decisions=0, n_blockers=0):
    """
    Update the thread record's updated_at timestamp, status, and scoring
    parameters. Uses read-dedup-modify-write since the hook runs at session
    end with no concurrent writers.

    Also reconciles: if thread_slug is detected but has no record in
    threads.jsonl, create a basic record so the thread enters the store.
    """
    if not thread_slug:
        return False

    ts = now_iso()
    threads_path = db / "threads.jsonl"
    records = read_jsonl(threads_path)
    records = dedup_by_id(records)

    # The inbox pseudo-thread gets a special record but never gets
    # scoring adjustments or status changes from individual sessions.
    is_inbox = thread_slug == INBOX_SLUG

    # Find matching record by slug
    found = False
    updated = False
    for rec in records:
        rec_slug = rec.get("slug") or rec.get("id", "").replace("thread:", "")
        if rec_slug == thread_slug:
            found = True
            # Update timestamp (handle both naming conventions)
            if rec.get("updated_at") is not None:
                rec["updated_at"] = ts
            if rec.get("updatedAt") is not None:
                rec["updatedAt"] = ts
            if "updated_at" not in rec and "updatedAt" not in rec:
                rec["updated_at"] = ts
                rec["updatedAt"] = ts
            if new_status and new_status != rec.get("status"):
                rec["status"] = new_status
                updated = True
            else:
                updated = True
            break

    if not found:
        thread_id = f"thread:{thread_slug}"
        if is_inbox:
            new_record = {
                "id": thread_id,
                "type": "thread",
                "slug": thread_slug,
                "title": "Inbox (unclassified)",
                "kind": "inbox",
                "status": "active",
                "stage": "inbox",
                "path": "inbox",
                "scope": scope,
                "schema_version": 1,
                "source": "auto-created-by-hook",
                "created_at": ts,
                "updated_at": ts,
                "createdAt": ts,
                "updatedAt": ts,
            }
        else:
            new_record = {
                "id": thread_id,
                "type": "thread",
                "slug": thread_slug,
                "title": thread_slug.replace("-", " ").title(),
                "kind": "project",
                "status": "active",
                "stage": "active",
                "path": f"threads/{thread_slug}",
                "scope": scope,
                "schema_version": 1,
                "source": "auto-created-by-hook",
                "created_at": ts,
                "updated_at": ts,
                "createdAt": ts,
                "updatedAt": ts,
            }
        records.append(new_record)
        updated = True

    # Adjust scoring parameters based on session content (item 3)
    # Skip for inbox pseudo-thread — it's ranked separately
    if not is_inbox and adjust_thread_scores(records, thread_slug, n_decisions, n_blockers, new_status):
        updated = True

    if updated:
        write_jsonl(threads_path, records)

    return updated


def write_thread_session_edge(db, scope, session_id_str, thread_slug):
    """Write an edge linking the session to the thread."""
    if not thread_slug:
        return
    ts = now_iso()
    edge = {
        "id": f"edge:session-{slugify(session_id_str)}-belongs-{thread_slug}",
        "type": "edge",
        "from": f"session:{slugify(session_id_str)}",
        "to": f"thread:{thread_slug}",
        "relationship": "session_of",
        "scope": scope,
        "schema_version": 1,
        "created_at": ts,
        "updated_at": ts,
    }
    append_jsonl(db / "edges.jsonl", edge)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    session_file = Path(os.environ.get("THREAD_OS_SESSION_FILE", ""))
    event_file = Path(os.environ.get("THREAD_OS_EVENT_FILE", ""))

    if not session_file.exists():
        sys.exit(0)

    session = load_json(session_file)
    if not session:
        sys.exit(0)

    event = load_json(event_file)

    # Resolve scope and repo
    scope, repo, workspace = resolve_scope_and_repo()
    if not scope or repo is None or workspace is None:
        sys.exit(0)

    workspace.mkdir(parents=True, exist_ok=True)
    db = workspace / ".lifeos" / "db"
    db.mkdir(parents=True, exist_ok=True)

    # Build summary text for matching
    summary = (
        event.get("summary")
        or event.get("sessionSummary")
        or event.get("transcriptSummary")
        or session.get("summary")
        or ""
    )
    accomplished = session.get("accomplished") or event.get("accomplished") or []
    incomplete = session.get("incomplete") or event.get("incomplete") or []

    # Add accomplished/incomplete text to the matching corpus
    match_corpus = " ".join([summary] + [str(x) for x in accomplished] + [str(x) for x in incomplete])

    # Resolve thread association
    thread_slug, match_method, _ = resolve_thread(workspace, session, match_corpus)

    # If no thread matched, route everything to the inbox pseudo-thread
    # so decisions/blockers/sessions are linked and surfaceable.
    if not thread_slug:
        thread_slug = INBOX_SLUG
        match_method = "inbox"

    # --- Existing behavior (preserved) ---

    # 1. Write session markdown note
    session_note_path = write_session_note(
        workspace, scope, session, event, thread_slug, match_method
    )

    # 2. Update TRACKER.md
    update_tracker(workspace, scope)

    # --- New behavior: bridge to JSONL store ---

    session_id_str = str(
        session.get("sessionId") or event.get("sessionId") or new_id("session")
    )

    # 3. Write session record
    write_session_record(
        db, scope, session, event, thread_slug, match_method, session_note_path
    )

    # 4. Extract and write decisions
    decisions = extract_decisions(summary, accomplished)
    if decisions:
        write_decision_records(db, scope, session_id_str, thread_slug, decisions)

    # 5. Extract and write blockers
    blockers = extract_blockers(summary, incomplete)
    if blockers:
        write_blocker_records(db, scope, session_id_str, thread_slug, blockers)

    # 6. Update thread timestamp, status, and scoring parameters
    new_status = infer_thread_status(summary, accomplished, incomplete)
    update_thread_record(
        db, scope, thread_slug, session,
        new_status,
        n_decisions=len(decisions),
        n_blockers=len(blockers),
    )

    # 7. Write session-thread edge
    write_thread_session_edge(db, scope, session_id_str, thread_slug)

    # 8. Feedback loop: learn path/repo mappings for term/slug matches
    project_path = session.get("project") or ""
    update_thread_map(workspace, project_path, thread_slug, match_method)

    # 9. Regenerate FOCUS.md from current JSONL state
    write_focus_md(workspace, db)

    # Done — exit cleanly
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Never crash the session wrapper
        print(f"thread-os session sync error: {e}", file=sys.stderr)
        sys.exit(0)
