#!/usr/bin/env bash
set -euo pipefail

project_roots() {
  find "$HOME/git/github.com" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true
  find "$HOME/projects" "$HOME/work" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true
}

icon_for() {
  case "$1" in
    openclaw*) printf '🐙' ;;
    pi*) printf '🤖' ;;
    hubble*) printf '🏦' ;;
    *starrocks*) printf '📊' ;;
    *flink*) printf '🧪' ;;
    *paimon*) printf '📦' ;;
    *) printf '📁' ;;
  esac
}

workspace_for_path() {
  herdr pane list 2>/dev/null | jq -r --arg path "$1" '
    .result.panes[]?
    | select((.cwd == $path) or (.foreground_cwd == $path) or (.cwd | startswith($path + "/")) or (.foreground_cwd | startswith($path + "/")))
    | .workspace_id
  ' | head -n 1
}

repo_dest() {
  local url=$1 name owner_repo
  name=${url##*/}
  name=${name%.git}

  if [[ $url =~ github.com[:/]([^/]+)/([^/]+)(\.git)?/?$ ]]; then
    owner_repo=${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}
    printf '%s/git/github.com/%s\n' "$HOME" "$owner_repo"
  else
    printf '%s/projects/%s\n' "$HOME" "$name"
  fi
}

mode_rows() {
  printf 'recent\t⭐ Recent\tExisting Herdr workspaces\n'
  printf 'projects\t📁 Open Project\tKnown local repos\n'
  printf 'actions\t⚡ Actions\tCreate, clone, worktree\n'
}

recent_rows() {
  herdr workspace list 2>/dev/null | jq -r '
    .result.workspaces[]?
    | "⭐ " + .label + "\t#" + (.number|tostring) + " · " + (.pane_count|tostring) + " panes · " + .agent_status + "\tworkspace:" + .workspace_id
  ' || true
}

project_rows() {
  project_roots | sort -u | while IFS= read -r dir; do
    name=$(basename "$dir")
    printf '%s %s\t%s\tproject:%s\n' "$(icon_for "$name")" "$name" "$dir" "$dir"
  done
}

action_rows() {
  printf 'Create workspace\tPrompt for cwd\taction:create-workspace\n'
  printf 'Clone repository\tgit clone, then open workspace\taction:clone-repository\n'
  printf 'New worktree\tFrom current cwd\taction:new-worktree\n'
}

rows_for_mode() {
  case "$1" in
    recent) recent_rows ;;
    projects) project_rows ;;
    actions) action_rows ;;
  esac
}

open_project() {
  local dir=$1 id label
  id=$(workspace_for_path "$dir")
  if [ -n "$id" ]; then
    herdr workspace focus "$id"
    return
  fi

  label=$(basename "$dir")
  herdr workspace create --cwd "$dir" --label "$label" --focus >/dev/null
}

create_workspace() {
  local cwd
  printf 'Workspace cwd [%s]: ' "$PWD" >&2
  IFS= read -r cwd
  cwd=${cwd:-$PWD}
  herdr workspace create --cwd "$cwd" --label "$(basename "$cwd")" --focus >/dev/null
}

clone_repository() {
  local url dest
  printf 'Repository URL: ' >&2
  IFS= read -r url
  [ -n "$url" ] || return 0

  dest=$(repo_dest "$url")
  mkdir -p "$(dirname "$dest")"
  if [ ! -e "$dest" ]; then
    git clone "$url" "$dest"
  fi
  open_project "$dest"
}

new_worktree() {
  local branch
  printf 'New worktree branch: ' >&2
  IFS= read -r branch
  [ -n "$branch" ] || return 0
  herdr worktree create --cwd "$PWD" --branch "$branch" --label "$(basename "$branch")" --focus >/dev/null
}

select_mode() {
  mode_rows | fzf --height=50% --border --delimiter=$'\t' --with-nth=2,3 --prompt='Palette mode> ' | awk -F '\t' '{print $1}'
}

select_row() {
  local mode=$1 prompt
  case "$mode" in
    recent) prompt='Recent> ' ;;
    projects) prompt='Open Project> ' ;;
    actions) prompt='Actions> ' ;;
    *) return 1 ;;
  esac

  rows_for_mode "$mode" | fzf --ansi --height=80% --border --delimiter=$'\t' --with-nth=1,2 --prompt="$prompt"
}

handle_payload() {
  local payload=$1 kind value
  kind=${payload%%:*}
  value=${payload#*:}

  case "$kind" in
    workspace) herdr workspace focus "$value" ;;
    project) open_project "$value" ;;
    action)
      case "$value" in
        create-workspace) create_workspace ;;
        clone-repository) clone_repository ;;
        new-worktree) new_worktree ;;
      esac
      ;;
  esac
}

self_test() {
  local old_home=$HOME
  HOME=/tmp/herdr-test
  [ "$(repo_dest 'git@github.com:kisw/openclaw.git')" = '/tmp/herdr-test/git/github.com/kisw/openclaw' ]
  [ "$(repo_dest 'https://github.com/lunarway/hubble')" = '/tmp/herdr-test/git/github.com/lunarway/hubble' ]
  [ "$(repo_dest 'ssh://git.example.com/repo.git')" = '/tmp/herdr-test/projects/repo' ]
  [ "$(mode_rows | awk 'NR==2 {print $1}')" = 'projects' ]
  HOME=$old_home
}

main() {
  local mode selected payload
  if [ "${1:-}" = "--self-test" ]; then
    self_test
    return
  fi

  mode=${1:-}
  case "$mode" in
    recent|projects|actions) ;;
    "") mode=$(select_mode) || return 0 ;;
    *)
      printf 'Usage: %s [recent|projects|actions]\n' "${0##*/}" >&2
      return 2
      ;;
  esac

  selected=$(select_row "$mode") || return 0
  payload=$(printf '%s\n' "$selected" | awk -F '\t' '{print $3}')
  handle_payload "$payload"
}

main "$@"
