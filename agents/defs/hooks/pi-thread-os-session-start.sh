#!/usr/bin/env bash
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! command -v jq >/dev/null || ! command -v python3 >/dev/null; then
  echo "thread-os: jq/python3 missing; session hook skipped" >&2
  exit 0
fi

SESSION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/sessions/${NAX_PROFILE:-default}/$(basename "$PWD")"
mkdir -p "$SESSION_DIR"
SESSION_FILE="$SESSION_DIR/$(date -u +%Y-%m-%dT%H-%M-%S).json"
SESSION_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")"
SKILL_VERSIONS="$(cat "${NAX_SKILL_VERSIONS:-/dev/null}" 2>/dev/null || echo '{}')"

jq -n \
  --arg id "$SESSION_ID" \
  --arg profile "${NAX_PROFILE:-default}" \
  --arg project "$PWD" \
  --arg ts "$(date -u +%FT%TZ)" \
  --argjson skillVersions "$SKILL_VERSIONS" \
  '{version: 1, sessionId: $id, profile: $profile, project: $project, startedAt: $ts, endedAt: null, branch: null, lastCommit: null, durationSec: null, tokenUsage: null, skillVersions: $skillVersions, accomplished: [], incomplete: [], events: []}' \
  > "$SESSION_FILE"

_NAX_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/${NAX_WRAPPER_PID:-$$}"
mkdir -p "$_NAX_STATE_DIR"
echo "$SESSION_FILE" > "$_NAX_STATE_DIR/current-session"
echo "$SESSION_ID" > "$_NAX_STATE_DIR/session-id"

THREAD_OS_SESSION_FILE="$SESSION_FILE" \
  python3 "$HOOKS_DIR/session-thread-context.py" \
  || echo "thread-os: context injection failed (non-fatal)" >&2
