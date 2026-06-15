# Thread OS Pi Extension

Native Pi commands for the git-backed Thread OS workspace.

## Commands

- `/thread-os status` — show repo/scope/workspace/store/write/git state.
- `/thread-os new-thread <title> --kind <kind>` — create a thread skeleton and append `threads.jsonl`.
- `/thread-os thread <slug>` — select the active thread for this Pi session.
- `/thread-os capture [text]` — queue a candidate, or capture `decision: ...` against the active thread.
- `/thread-os focus` — rank active threads from JSONL records.
- `/thread-os render` — update generated sections in `TRACKER.md`, `FOCUS.md`, and thread READMEs.

## Scope and repo resolution

Repo resolution is scope-aware:

- personal scope uses `THREAD_OS_PERSONAL_REPO`, then `~/git/github.com/kirksw/lifeOS`
- lunar/work scope uses `THREAD_OS_WORK_REPO`, then `~/git/github.com/kirksw/lunarOS`

Workspace resolution uses `repo/workspace`.

Scope is profile/base authoritative when `THREAD_OS_SCOPE`, `NAX_BASE`, `NAX_PROFILE`, or `PI_CODING_AGENT_DIR` are present. Unknown scopes disable writes.

Auto-commit is intentionally not implemented/enabled in v0; writes remain direct working-tree changes in the Thread OS repo.
