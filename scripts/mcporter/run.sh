#!/usr/bin/env bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
stage="$(mktemp -d "${TMPDIR:-/tmp}/mcporter-tooling.XXXXXXXX")"
trap 'rm -rf "$stage"' EXIT
cp "$source_dir/package.json" "$source_dir/package-lock.json" "$stage/"
(cd "$stage" && npm ci --ignore-scripts --no-audit --no-fund) >&2
patch --batch --forward -d "$stage/node_modules/mcporter" -p1 < "$source_dir/session-cleanup.patch" >&2
if [ "${1:-}" = --script ]; then
  shift
  script="$1"
  shift
  MCPORTER_TOOLING_ROOT="$stage/node_modules/mcporter" node "$script" "$@"
else
  node "$stage/node_modules/mcporter/dist/cli.js" "$@"
fi
