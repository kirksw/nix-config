#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

exec "${SCRIPT_DIR}/wezterm-popup-toggle.sh" \
  "ai" \
  "${HOME}/git/github.com/kirksw/scratchpad" \
  "ai-popup" \
  "70" \
  "60"
