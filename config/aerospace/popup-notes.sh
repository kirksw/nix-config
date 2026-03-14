#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/wezterm-popup-toggle.sh" \
  "notes" \
  "${HOME}/git/github.com/kirksw/notes" \
  "notes-popup" \
  "70" \
  "60"
