#!/usr/bin/env bash

set -euo pipefail

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER}/bin:${HOME}/.nix-profile/bin:${PATH}"

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <popup_name> <cwd> <sesh_target> [width_pct] [height_pct]" >&2
  exit 2
fi

popup_name="$1"
cwd="$2"
sesh_target="$3"
width_pct="${4:-70}"
height_pct="${5:-60}"

cache_dir="${HOME}/.cache/aerospace-popups"
state_file="${cache_dir}/${popup_name}.window-id"

mkdir -p "${cache_dir}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

require_cmd aerospace
require_cmd wezterm
require_cmd sesh

current_workspace="$(aerospace list-workspaces --focused)"

list_workspaces() {
  aerospace list-workspaces --all 2>/dev/null || aerospace list-workspaces
}

window_exists() {
  local window_id="$1"
  aerospace list-windows --all --format "%{window-id}" | grep -Fxq "${window_id}"
}

workspace_for_window() {
  local window_id="$1"
  local workspace=""
  while IFS= read -r workspace; do
    [[ -z "${workspace}" ]] && continue
    if aerospace list-windows --workspace "${workspace}" --format "%{window-id}" | grep -Fxq "${window_id}"; then
      printf '%s\n' "${workspace}"
      return 0
    fi
  done < <(list_workspaces)

  return 1
}

set_floating_geometry() {
  local window_id="$1"
  local w_pct="$2"
  local h_pct="$3"
  local desktop_bounds=""
  local x1="" y1="" x2="" y2=""
  local screen_w="" screen_h=""
  local win_w="" win_h=""
  local pos_x="" pos_y=""
  local i=""

  for i in $(seq 1 8); do
    aerospace focus --window-id "${window_id}" >/dev/null 2>&1 || true
    aerospace macos-native-fullscreen off --window-id "${window_id}" --fail-if-noop >/dev/null 2>&1 || true
    aerospace fullscreen off --window-id "${window_id}" --fail-if-noop >/dev/null 2>&1 || true
    aerospace layout floating --window-id "${window_id}" >/dev/null 2>&1 || true
    osascript >/dev/null 2>&1 <<'EOF' || true
tell application "System Events"
  tell process "WezTerm"
    if exists front window then
      try
        set value of attribute "AXFullScreen" of front window to false
      end try
      try
        set zoomed of front window to false
      end try
    end if
  end tell
end tell
EOF
    sleep 0.05
  done

  desktop_bounds="$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)"
  if [[ -z "${desktop_bounds}" ]]; then
    return 0
  fi

  IFS=', ' read -r x1 y1 x2 y2 <<< "${desktop_bounds}"
  if [[ -z "${x2}" || -z "${y2}" ]]; then
    return 0
  fi

  screen_w=$((x2 - x1))
  screen_h=$((y2 - y1))
  win_w=$((screen_w * w_pct / 100))
  win_h=$((screen_h * h_pct / 100))
  pos_x=$((x1 + (screen_w - win_w) / 2))
  pos_y=$((y1 + (screen_h - win_h) / 2))

  osascript >/dev/null 2>&1 <<EOF || true
tell application "System Events"
  tell process "WezTerm"
    if exists front window then
      set position of front window to {${pos_x}, ${pos_y}}
      set size of front window to {${win_w}, ${win_h}}
    end if
  end tell
end tell
EOF

  # Some setups can re-enter tiled/fullscreen right after resize; apply final guard.
  aerospace macos-native-fullscreen off --window-id "${window_id}" --fail-if-noop >/dev/null 2>&1 || true
  aerospace fullscreen off --window-id "${window_id}" --fail-if-noop >/dev/null 2>&1 || true
  aerospace layout floating --window-id "${window_id}" >/dev/null 2>&1 || true
}

read_window_id() {
  if [[ ! -f "${state_file}" ]]; then
    return 1
  fi

  local stored_id=""
  stored_id="$(tr -d '[:space:]' < "${state_file}")"
  if [[ -z "${stored_id}" ]]; then
    return 1
  fi

  printf '%s\n' "${stored_id}"
}

persist_window_id() {
  local window_id="$1"
  printf '%s\n' "${window_id}" > "${state_file}"
}

clear_window_id() {
  rm -f "${state_file}"
}

spawn_popup_window() {
  local -a before_ids=()
  local -a after_ids=()
  local before_file=""
  local after_file=""
  local new_window_id=""
  local i=""
  local cmd=""

  mapfile -t before_ids < <(
    aerospace list-windows --all --format "%{window-id}|%{app-name}" \
      | awk -F'|' '$2 == "WezTerm" { print $1 }'
  )

  before_file="$(mktemp)"
  after_file="$(mktemp)"
  trap 'rm -f "${before_file}" "${after_file}"' RETURN

  if ((${#before_ids[@]} > 0)); then
    printf '%s\n' "${before_ids[@]}" | sort -u > "${before_file}"
  else
    : > "${before_file}"
  fi

  cmd="if ! sesh connect $(printf '%q' "${sesh_target}"); then echo \"sesh connect failed: ${sesh_target}\"; exec zsh -il; fi"
  wezterm start --always-new-process --cwd "${cwd}" -- zsh -lc "${cmd}" >/dev/null 2>&1 &

  for i in $(seq 1 60); do
    sleep 0.1

    mapfile -t after_ids < <(
      aerospace list-windows --all --format "%{window-id}|%{app-name}" \
        | awk -F'|' '$2 == "WezTerm" { print $1 }'
    )

    if ((${#after_ids[@]} == 0)); then
      continue
    fi

    printf '%s\n' "${after_ids[@]}" | sort -u > "${after_file}"
    new_window_id="$(comm -13 "${before_file}" "${after_file}" | head -n 1 || true)"

    if [[ -n "${new_window_id}" ]]; then
      printf '%s\n' "${new_window_id}"
      return 0
    fi
  done

  return 1
}

toggle_existing_popup() {
  local window_id="$1"
  local window_workspace=""

  if ! window_workspace="$(workspace_for_window "${window_id}")"; then
    clear_window_id
    return 1
  fi

  if [[ "${window_workspace}" == "${current_workspace}" ]]; then
    aerospace close --window-id "${window_id}"
    clear_window_id
    return 0
  fi

  aerospace move-node-to-workspace "${current_workspace}" --window-id "${window_id}"
  aerospace focus --window-id "${window_id}"
  set_floating_geometry "${window_id}" "${width_pct}" "${height_pct}"
  persist_window_id "${window_id}"
  return 0
}

main() {
  local window_id=""
  local new_window_id=""

  if window_id="$(read_window_id)"; then
    if window_exists "${window_id}" && toggle_existing_popup "${window_id}"; then
      return 0
    fi
  fi

  clear_window_id

  if ! new_window_id="$(spawn_popup_window)"; then
    echo "failed to discover new WezTerm popup window id for ${popup_name}" >&2
    exit 1
  fi

  aerospace move-node-to-workspace "${current_workspace}" --window-id "${new_window_id}"
  aerospace focus --window-id "${new_window_id}"
  set_floating_geometry "${new_window_id}" "${width_pct}" "${height_pct}"
  persist_window_id "${new_window_id}"
}

main "$@"
