#!/usr/bin/env bash
set -euo pipefail
app="$HOME/Applications/EDGE Observatory.app"
if [[ ! -x "$app/Contents/MacOS/EDGE Observatory" ]]; then
  printf 'Build the app first: bash scripts/build-edge-observatory.sh\n' >&2
  exit 1
fi
open "$app"
