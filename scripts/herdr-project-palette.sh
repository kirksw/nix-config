#!/usr/bin/env bash
set -euo pipefail

project_roots() {
  find "$HOME/git/github.com" -mindepth 2 -maxdepth 2 -type d 2>/dev/null || true
  find "$HOME/projects" "$HOME/work" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true
}

icon_for() {
  local org repo
  case "$1" in
    "$HOME"/git/github.com/*/*)
      org=$(basename "$(dirname "$1")")
      repo=$(basename "$1")
      case "$org/$repo" in
        kirksw/lifeOS|kirksw/lunarOS) printf '⭐' ;;
        kirksw/nix-config) printf '⚙' ;;
        lunarway/*) printf '🏦' ;;
        kirksw/*) printf '🏠' ;;
        *) printf '📁' ;;
      esac
      ;;
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

ezgit_cmd() {
  command -v ezgit 2>/dev/null || {
    [ -x "$HOME/.nix-profile/bin/ezgit" ] && printf '%s\n' "$HOME/.nix-profile/bin/ezgit"
  } || {
    [ -n "${USER:-}" ] && [ -x "/etc/profiles/per-user/$USER/bin/ezgit" ] && printf '%s\n' "/etc/profiles/per-user/$USER/bin/ezgit"
  }
}

run_ezgit() {
  local bin
  bin=$(ezgit_cmd) || {
    printf 'ezgit not found\n' >&2
    return 127
  }
  "$bin" "$@"
}

repo_dest() {
  local url=$1 name owner_repo
  name=${url##*/}
  name=${name%.git}

  if [[ $url =~ github.com[:/]([^/]+)/([^/]+)(\.git)?/?$ ]]; then
    owner_repo=${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}
    printf '%s/git/github.com/%s\n' "$HOME" "$owner_repo"
  elif [[ $url =~ ^([^/:]+)/([^/]+)$ ]]; then
    printf '%s/git/github.com/%s/%s\n' "$HOME" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]%.git}"
  else
    printf '%s/projects/%s\n' "$HOME" "$name"
  fi
}

mode_rows() {
  printf 'recent\t⭐ Recent\tExisting Herdr workspaces\n'
  printf 'projects\t📁 Open Project\tKnown local repos\n'
  printf 'actions\t⚡ Actions\tCreate, clone, worktree\n'
  printf 'ezgit\t🐙 EzGit\tGitHub clone/cache helpers\n'
}

recent_rows() {
  herdr workspace list 2>/dev/null | jq -r '
    .result.workspaces[]?
    | "⭐ " + .label + "\t#" + (.number|tostring) + " · " + (.pane_count|tostring) + " panes · " + .agent_status + "\tworkspace:" + .workspace_id
  ' || true
}

project_label() {
  case "$1" in
    "$HOME"/git/github.com/*/*) printf 'gh:%s/%s\n' "$(basename "$(dirname "$1")")" "$(basename "$1")" ;;
    *) basename "$1" ;;
  esac
}

project_rows() {
  project_roots | sort -u | while IFS= read -r dir; do
    printf '%s %s\t%s\tproject:%s\n' "$(icon_for "$dir")" "$(project_label "$dir")" "$dir" "$dir"
  done
}

action_rows() {
  printf 'Create workspace\tPrompt for cwd\taction:create-workspace\n'
  printf 'Clone repository\tezgit if available, then open workspace\taction:clone-repository\n'
  printf 'New worktree\tFrom current cwd\taction:new-worktree\n'
}

ezgit_rows() {
  printf 'Clone/open repository\tezgit if available, then open workspace\taction:clone-repository\n'
  printf 'Refresh cache\tezgit cache refresh\taction:ezgit-refresh-cache\n'
  printf 'Open EzGit picker\trun ezgit with your configured open_command\taction:ezgit-picker\n'
}

rows_for_mode() {
  case "$1" in
    recent) recent_rows ;;
    projects) project_rows ;;
    actions) action_rows ;;
    ezgit) ezgit_rows ;;
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

openable_repo() {
  local dest=$1 dir top
  for dir in "$dest" "$dest/main" "$dest/master"; do
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) && {
      printf '%s\n' "$top"
      return
    }
  done

  find "$dest" -mindepth 1 -maxdepth 2 -type d 2>/dev/null | while IFS= read -r dir; do
    git -C "$dir" rev-parse --show-toplevel 2>/dev/null && break
  done
}

clone_repository() {
  local url dest repo
  printf 'Repository URL or owner/repo: ' >&2
  IFS= read -r url
  [ -n "$url" ] || return 0

  dest=$(repo_dest "$url")
  if ezgit_cmd >/dev/null; then
    run_ezgit --no-open "$url"
  else
    mkdir -p "$(dirname "$dest")"
    if [ ! -e "$dest" ]; then
      git clone "$url" "$dest"
    fi
  fi

  repo=$(openable_repo "$dest")
  open_project "${repo:-$dest}"
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
    ezgit) prompt='EzGit> ' ;;
    *) return 1 ;;
  esac

  if [ "$mode" = projects ]; then
    rows_for_mode "$mode" | fzf --ansi --height=80% --border --delimiter=$'\t' --with-nth=1 --prompt="$prompt"
  else
    rows_for_mode "$mode" | fzf --ansi --height=80% --border --delimiter=$'\t' --with-nth=1,2 --prompt="$prompt"
  fi
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
        ezgit-refresh-cache) run_ezgit cache refresh ;;
        ezgit-picker) run_ezgit ;;
      esac
      ;;
  esac
}

self_test() {
  local old_home=$HOME
  HOME=/tmp/herdr-test
  [ "$(repo_dest 'git@github.com:kisw/openclaw.git')" = '/tmp/herdr-test/git/github.com/kisw/openclaw' ]
  [ "$(repo_dest 'https://github.com/lunarway/hubble')" = '/tmp/herdr-test/git/github.com/lunarway/hubble' ]
  [ "$(repo_dest 'lunarway/hubble')" = '/tmp/herdr-test/git/github.com/lunarway/hubble' ]
  [ "$(repo_dest 'ssh://git.example.com/repo.git')" = '/tmp/herdr-test/projects/repo' ]
  [ "$(project_label '/tmp/herdr-test/git/github.com/lunarway/hubble')" = 'gh:lunarway/hubble' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/kirksw/lifeOS')" = '⭐' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/kirksw/lunarOS')" = '⭐' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/kirksw/nix-config')" = '⚙' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/lunarway/hubble')" = '🏦' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/kirksw/notes')" = '🏠' ]
  [ "$(icon_for '/tmp/herdr-test/git/github.com/other/repo')" = '📁' ]
  [ "$(mode_rows | awk 'NR==2 {print $1}')" = 'projects' ]
  [ "$(mode_rows | awk 'NR==4 {print $1}')" = 'ezgit' ]
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
    recent|projects|actions|ezgit) ;;
    "") mode=$(select_mode) || return 0 ;;
    *)
      printf 'Usage: %s [recent|projects|actions|ezgit]\n' "${0##*/}" >&2
      return 2
      ;;
  esac

  selected=$(select_row "$mode") || return 0
  payload=$(printf '%s\n' "$selected" | awk -F '\t' '{print $3}')
  handle_payload "$payload"
}

main "$@"
