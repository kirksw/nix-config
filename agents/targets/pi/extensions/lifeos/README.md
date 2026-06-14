# LifeOS Pi Extension

Native Pi commands for the git-backed LifeOS workspace.

## Commands

- `/lifeos status` — show repo/scope/workspace/store/write/git state.
- `/lifeos new-thread <title> --kind <kind>` — create a thread skeleton and append `threads.jsonl`.
- `/lifeos thread <slug>` — select the active thread for this Pi session.
- `/lifeos capture [text]` — queue a candidate, or capture `decision: ...` against the active thread.
- `/lifeos focus` — rank active threads from JSONL records.
- `/lifeos render` — update generated sections in `TRACKER.md`, `FOCUS.md`, and thread READMEs.

## Scope and repo resolution

Repo resolution uses `LIFEOS_REPO` first, then `~/git/github.com/kirksw/lifeOS`.
Scope is profile/base authoritative when `LIFEOS_SCOPE`, `NAX_BASE`, `NAX_PROFILE`, or `PI_CODING_AGENT_DIR` are present; otherwise cwd fallbacks are used. Unknown scopes disable writes.

Auto-commit is intentionally not implemented/enabled in v0; writes remain direct working-tree changes in the LifeOS repo.
