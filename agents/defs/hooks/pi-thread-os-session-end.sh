#!/usr/bin/env bash
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
if ! command -v jq >/dev/null || ! command -v python3 >/dev/null; then
  echo "thread-os: jq/python3 missing; session hook skipped" >&2
  exit 0
fi

SESSION_FILE="$(cat "${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/${NAX_WRAPPER_PID:-$$}/current-session" 2>/dev/null || true)"
if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then exit 0; fi

EVENT_FILE="$(mktemp 2>/dev/null || echo "$SESSION_FILE.event")"
cat > "$EVENT_FILE" 2>/dev/null || true
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || true)"
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

THREAD_OS_EVENT_FILE="$EVENT_FILE" \
THREAD_OS_SESSION_FILE="$SESSION_FILE" \
  python3 "$HOOKS_DIR/session-thread-sync.py" \
  || echo "thread-os: session sync failed (non-fatal)" >&2

rm -f "$EVENT_FILE"
rm -rf "${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/${NAX_WRAPPER_PID:-$$}"
