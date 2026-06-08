#!/usr/bin/env bash
set -eu

limit="${1:-40}"

roots=(
  "$HOME/.local/share/nix-agents"
  "$HOME/.codex"
  "$HOME/.claude"
  "$HOME/.pi"
  "$HOME/.config/nix-agents"
)

existing_roots=()
for root in "${roots[@]}"; do
  if [[ -d "$root" ]]; then
    existing_roots+=("$root")
  fi
done

if [[ "${#existing_roots[@]}" -eq 0 ]]; then
  exit 0
fi

stat_file() {
  if stat --version >/dev/null 2>&1; then
    stat -c $'%Y\t%s\t%n' "$1"
  else
    stat -f $'%m\t%z\t%N' "$1"
  fi
}

format_mtime() {
  if date -r "$1" -u '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -r "$1" -u '+%Y-%m-%dT%H:%M:%SZ'
  else
    date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'
  fi
}

find "${existing_roots[@]}" \
  -type f \( -name '*.json' -o -name '*.jsonl' -o -name '*.log' \) \
  -print0 2>/dev/null \
  | while IFS= read -r -d '' path; do
      case "$path" in
        */cache/*|*/models_cache.json|*/history.jsonl) continue ;;
      esac
      case "$path" in
        *.jsonl|*/nix-agents/sessions/*/*.json) ;;
        *) continue ;;
      esac
      stat_file "$path" 2>/dev/null || true
    done \
  | sort -rn \
  | head -n "$limit" \
  | while IFS="$(printf '\t')" read -r mtime size path; do
      tool="unknown"
      case "$path" in
        *"/.codex/"*|*"/nix-agents/codex/"*) tool="codex" ;;
        *"/.claude/"*|*"/nix-agents/claude/"*) tool="claude" ;;
        *"/.pi/"*|*"/nix-agents/pi/"*) tool="pi" ;;
        *"/nix-agents/sessions/"*) tool="nix-agents-summary" ;;
      esac

      signals="$(rg -i -c 'error|failed|exception|denied|permission|sandbox|retry|fixed|passed|actually|instead|not what|complete|success' "$path" 2>/dev/null || true)"
      signals="${signals:-0}"
      printf '%s\t%s\t%s\t%s\t%s\n' "$(format_mtime "$mtime")" "$tool" "$signals" "$size" "$path"
    done
