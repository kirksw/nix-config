#!/usr/bin/env bash
set -euo pipefail

herdr_bin="${1:-herdr}"
grep_bin="${GREP:-grep}"

check_command() {
  group="$1"
  command="$2"
  shift 2

  help="$($herdr_bin "$group" "$command" --help)"
  for flag in "$@"; do
    if ! "$grep_bin" -Fq -- "$flag" <<<"$help"; then
      echo "Herdr compatibility check failed: '$group $command' lacks '$flag'" >&2
      exit 1
    fi
  done
}

"$herdr_bin" --version >/dev/null

check_command workspace get
check_command workspace list
check_command workspace create --cwd --label --no-focus
check_command workspace focus

check_command tab list --workspace
check_command tab create --workspace --cwd --label --no-focus
check_command tab focus

check_command pane get
check_command pane list --workspace
check_command pane split --direction --cwd --no-focus --right-click
check_command pane run
check_command pane read --source --lines --raw
check_command pane wait-output --match --regex --source --lines --timeout --raw
check_command pane send-text
check_command pane send-keys
check_command pane close
