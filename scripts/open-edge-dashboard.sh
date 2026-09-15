#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
page_url="http://127.0.0.1:8767/"
if ! curl --fail --silent --max-time 2 "$page_url/api/agents" >/dev/null; then
  printf 'Start the dashboard service first: python3 %s/config/edge-dashboard/server.py\n' "$repo_root" >&2
  exit 1
fi
profile_dir="${HOME}/Library/Application Support/edge-dashboard/chrome"

# A separate Chrome profile keeps dashboard windows apart from normal browsing.
open -na 'Google Chrome' --args \
  "--user-data-dir=$profile_dir" \
  --no-first-run \
  --no-default-browser-check \
  "--app=$page_url"

if ! command -v aerospace >/dev/null 2>&1; then
  printf 'Dashboard opened. AeroSpace is unavailable; position the window manually.\n'
  exit 0
fi

for ((attempt = 0; attempt < 30; attempt++)); do
  window_id="$(aerospace list-windows --all --format '%{window-id}|%{app-bundle-id}|%{window-title}' |
    awk -F '|' '$2 == "com.google.Chrome" && $3 == "EDGE / Observatory" {print $1; exit}')"
  if [[ -n "$window_id" ]]; then
    # Native fullscreen uses a separate macOS Space; exit it before repositioning.
    aerospace macos-native-fullscreen off --window-id "$window_id"
    sleep 1
    aerospace fullscreen off --window-id "$window_id"
    aerospace move-node-to-workspace dashboard --window-id "$window_id"
    aerospace workspace dashboard
    aerospace focus --window-id "$window_id"
    # Allow the display/Space transition to finish before creating a fullscreen Space.
    sleep 1
    aerospace macos-native-fullscreen on --window-id "$window_id"
    exit 0
  fi
  sleep 0.5
done

printf 'Dashboard launched, but its window was not detected. Move it to dashboard manually.\n' >&2
exit 1
