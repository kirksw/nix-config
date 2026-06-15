# Session tracking hooks: write JSON session files on start/end.
# Usage: import this file as a function receiving pkgs, then merge into your module list.
# Example (in flake.nix or preset):
#   modules = defaultModules ++ [ (import ./defs/hooks/session-write.nix { inherit pkgs; }) ];
{ pkgs }:
{
  hooks = [
    {
      event = "session-start";
      package = pkgs.jq;
      command = ''
        SESSION_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/sessions/''${NAX_PROFILE:-default}/$(basename "$PWD")"
        mkdir -p "$SESSION_DIR"
        SESSION_FILE="$SESSION_DIR/$(date -u +%Y-%m-%dT%H-%M-%S).json"
        SESSION_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")"
        SKILL_VERSIONS="$(cat "''${NAX_SKILL_VERSIONS:-/dev/null}" 2>/dev/null || echo '{}')"
        jq -n \
          --arg id "$SESSION_ID" \
          --arg profile "''${NAX_PROFILE:-default}" \
          --arg project "$PWD" \
          --arg ts "$(date -u +%FT%TZ)" \
          --argjson skillVersions "$SKILL_VERSIONS" \
          '{
            version: 1,
            sessionId: $id,
            profile: $profile,
            project: $project,
            startedAt: $ts,
            endedAt: null,
            branch: null,
            lastCommit: null,
            durationSec: null,
            tokenUsage: null,
            skillVersions: $skillVersions,
            accomplished: [],
            incomplete: [],
            events: []
          }' > "$SESSION_FILE"
        _NAX_STATE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
        mkdir -p "$_NAX_STATE_DIR"
        echo "$SESSION_FILE" > "$_NAX_STATE_DIR/current-session"
        echo "$SESSION_ID" > "$_NAX_STATE_DIR/session-id"
      '';
    }
    {
      event = "session-end";
      package = pkgs.symlinkJoin {
        name = "nix-agents-session-end-tools";
        paths = [
          pkgs.jq
          pkgs.python3
        ];
      };
      command = ''
                SESSION_FILE="$(cat "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}/current-session" 2>/dev/null)"
                if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then exit 0; fi
                EVENT_FILE="$(mktemp 2>/dev/null || echo "$SESSION_FILE.event")"
                cat > "$EVENT_FILE" 2>/dev/null || true
                BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
                COMMIT="$(git rev-parse --short HEAD 2>/dev/null)"
                STARTED="$(jq -r .startedAt "$SESSION_FILE")"
                START_EPOCH="$(date -d "$STARTED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" +%s 2>/dev/null || echo 0)"
                DURATION="$(( $(date +%s) - START_EPOCH ))"
                jq \
                  --arg end "$(date -u +%FT%TZ)" \
                  --arg branch "$BRANCH" \
                  --arg commit "$COMMIT" \
                  --argjson dur "$DURATION" \
                  '.endedAt = $end | .branch = $branch | .lastCommit = $commit | .durationSec = $dur' \
                  "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

                THREAD_OS_EVENT_FILE="$EVENT_FILE" THREAD_OS_SESSION_FILE="$SESSION_FILE" python3 <<'PY'
        import json
        import os
        import re
        from datetime import datetime, timezone
        from pathlib import Path

        personal_repo = Path(os.environ.get("THREAD_OS_PERSONAL_REPO", "/Users/kisw/git/github.com/kirksw/lifeOS"))
        work_repo = Path(os.environ.get("THREAD_OS_WORK_REPO", "/Users/kisw/git/github.com/kirksw/lunarOS"))
        session_file = Path(os.environ.get("THREAD_OS_SESSION_FILE", ""))
        if not session_file.exists():
            raise SystemExit(0)

        try:
            data = json.loads(session_file.read_text())
        except Exception:
            raise SystemExit(0)

        try:
            event_file = Path(os.environ.get("THREAD_OS_EVENT_FILE", ""))
            event = json.loads(event_file.read_text()) if event_file.exists() and event_file.stat().st_size > 0 else {}
        except Exception:
            event = {}

        profile = data.get("profile") or os.environ.get("NAX_PROFILE", "")
        if profile.startswith("personal"):
            scope = "personal"
            repo = personal_repo
        elif profile.startswith("work"):
            scope = "lunar"
            repo = work_repo
        else:
            raise SystemExit(0)

        if not repo.exists():
            raise SystemExit(0)

        workspace = repo / "workspace"
        workspace.mkdir(parents=True, exist_ok=True)
        tracker = workspace / "TRACKER.md"
        if not tracker.exists():
            tracker.write_text(
                "# " + scope.title() + " Tracker\n\n"
                "<!-- lifeos:generated:start -->\n"
                "_No generated activity yet._\n"
                "<!-- lifeos:generated:end -->\n\n"
                "## Manual notes\n\n"
            )

        def slugify(value):
            value = (value or "").strip().lower()
            value = re.sub(r"[^a-z0-9]+", "-", value).strip("-")
            return value or "session"

        project_path = data.get("project") or ""
        project_name = Path(project_path).name if project_path else ""
        project_slug = slugify(project_name)
        project_dir = workspace / project_slug
        use_inbox = project_slug in {"", "session", "home"} or not project_dir.exists()

        if use_inbox:
            target_dir = workspace / "inbox"
            if project_slug in {"", "session", "home"}:
                assoc = "No clear project path was available; routed to workspace inbox."
            else:
                assoc = "No existing project matched path basename `" + project_slug + "`; routed to workspace inbox instead of creating a project automatically."
        else:
            target_dir = project_dir
            assoc = "Associated by Pi profile and existing project directory `" + project_slug + "`."

        sessions_dir = target_dir / "sessions"
        sessions_dir.mkdir(parents=True, exist_ok=True)
        ended_at = data.get("endedAt") or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        date_part = ended_at[:10] if len(ended_at) >= 10 else datetime.now(timezone.utc).strftime("%Y-%m-%d")
        time_part = ended_at[11:19].replace(":", "-") if len(ended_at) >= 19 else datetime.now(timezone.utc).strftime("%H-%M-%S")
        file_slug = project_slug if not use_inbox else "investigatory-session"
        session_id = slugify(str(data.get("sessionId") or event.get("sessionId") or "session"))
        session_note = sessions_dir / (date_part + "-" + time_part + "-" + file_slug + "-" + session_id + ".md")
        if session_note.exists():
            suffix = 1
            while True:
                candidate = session_note.with_name(session_note.stem + "-" + str(suffix) + session_note.suffix)
                if not candidate.exists():
                    session_note = candidate
                    break
                suffix += 1

        summary = (
            event.get("summary")
            or event.get("sessionSummary")
            or event.get("transcriptSummary")
            or data.get("summary")
            or "Session metadata captured automatically. Review and expand this note with outcomes, decisions, and next actions."
        )
        accomplished = data.get("accomplished") or event.get("accomplished") or []
        incomplete = data.get("incomplete") or event.get("incomplete") or []
        started = data.get("startedAt") or "unknown"
        duration = data.get("durationSec")
        duration_text = str(duration) + " seconds" if isinstance(duration, int) else "unknown"
        branch = data.get("branch") or "unknown"
        commit = data.get("lastCommit") or "unknown"

        def md_items(items, empty):
            if not items:
                return empty + "\n"
            return "".join("- " + str(item) + "\n" for item in items)

        session_note.write_text(
            "# Session " + date_part + " " + time_part.replace("-", ":") + " UTC\n\n"
            "## Metadata\n\n"
            "- Profile: `" + profile + "`\n"
            "- Workspace: `" + scope + "`\n"
            "- Project path: `" + (project_path or "unknown") + "`\n"
            "- Branch: `" + branch + "`\n"
            "- Commit: `" + commit + "`\n"
            "- Started: `" + started + "`\n"
            "- Ended: `" + ended_at + "`\n"
            "- Duration: " + duration_text + "\n\n"
            "## Summary\n\n"
            + summary + "\n\n"
            "## Accomplished\n\n"
            + md_items(accomplished, "_No accomplishments were captured automatically._") + "\n"
            "## Incomplete\n\n"
            + md_items(incomplete, "_No incomplete items were captured automatically._") + "\n"
            "## Associativity\n\n"
            + assoc + "\n\n"
            "## Next actions\n\n"
            "- [ ] Review this generated summary.\n"
            "- [ ] Update project context and tracker manual notes if needed.\n"
        )

        def latest_session(project_dir):
            sessions = sorted((project_dir / "sessions").glob("*.md"), key=lambda p: p.stat().st_mtime, reverse=True)
            return sessions[0] if sessions else None

        project_lines = []
        for child in sorted(workspace.iterdir(), key=lambda p: p.name):
            if not child.is_dir() or child.name == "inbox":
                continue
            latest = latest_session(child)
            session_count = len(list((child / "sessions").glob("*.md"))) if (child / "sessions").exists() else 0
            latest_link = "none"
            if latest:
                latest_link = "[" + latest.name + "](" + latest.relative_to(workspace).as_posix() + ")"
            project_lines.append("- `" + child.name + "` — " + str(session_count) + " session(s); latest: " + latest_link)

        inbox_sessions = list((workspace / "inbox" / "sessions").glob("*.md")) if (workspace / "inbox" / "sessions").exists() else []
        generated = [
            "<!-- lifeos:generated:start -->",
            "_Last updated: " + datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") + "._",
            "",
            "## Active projects",
            "",
        ]
        generated.extend(project_lines or ["_No project sessions yet._"])
        generated.extend([
            "",
            "## Inbox",
            "",
            "- " + str(len(inbox_sessions)) + " unclassified session(s).",
            "<!-- lifeos:generated:end -->",
        ])
        new_block = "\n".join(generated)
        text = tracker.read_text()
        pattern = re.compile(r"<!-- lifeos:generated:start -->.*?<!-- lifeos:generated:end -->", re.S)
        matches = list(pattern.finditer(text))
        if len(matches) == 1:
            text = pattern.sub(new_block, text, count=1)
        elif len(matches) == 0:
            text = text.rstrip() + "\n\n" + new_block + "\n"
        else:
            raise SystemExit(0)
        tracker_tmp = tracker.with_suffix(tracker.suffix + ".tmp")
        tracker_tmp.write_text(text)
        tracker_tmp.replace(tracker)
        PY

                rm -f "$EVENT_FILE"
                rm -rf "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
      '';
    }
  ];
}
