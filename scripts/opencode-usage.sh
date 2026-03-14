#!/usr/bin/env bash
set -euo pipefail

STORAGE_DIR="$HOME/.local/share/opencode/storage"
MESSAGES_DIR="$STORAGE_DIR/message"
SESSIONS_DIR="$STORAGE_DIR/session"

# Pricing per 1M tokens (input, output, cache_read, cache_write)
# From https://opencode.ai/docs/zen/
declare -A PRICING_INPUT
declare -A PRICING_OUTPUT
declare -A PRICING_CACHE_READ
declare -A PRICING_CACHE_WRITE

# GLM models
PRICING_INPUT[glm-5]=1.00
PRICING_OUTPUT[glm-5]=3.20
PRICING_CACHE_READ[glm-5]=0.20

PRICING_INPUT[glm-4.7]=0.60
PRICING_OUTPUT[glm-4.7]=2.20
PRICING_CACHE_READ[glm-4.7]=0.10

PRICING_INPUT[glm-4.6]=0.60
PRICING_OUTPUT[glm-4.6]=2.20
PRICING_CACHE_READ[glm-4.6]=0.10

# GPT models
PRICING_INPUT[gpt-5.3-codex]=1.75
PRICING_OUTPUT[gpt-5.3-codex]=14.00
PRICING_CACHE_READ[gpt-5.3-codex]=0.175

PRICING_INPUT[gpt-5.2]=1.75
PRICING_OUTPUT[gpt-5.2]=14.00
PRICING_CACHE_READ[gpt-5.2]=0.175

PRICING_INPUT[gpt-5.2-codex]=1.75
PRICING_OUTPUT[gpt-5.2-codex]=14.00
PRICING_CACHE_READ[gpt-5.2-codex]=0.175

PRICING_INPUT[gpt-5.1]=1.07
PRICING_OUTPUT[gpt-5.1]=8.50
PRICING_CACHE_READ[gpt-5.1]=0.107

PRICING_INPUT[gpt-5.1-codex]=1.07
PRICING_OUTPUT[gpt-5.1-codex]=8.50
PRICING_CACHE_READ[gpt-5.1-codex]=0.107

PRICING_INPUT[gpt-5.1-codex-max]=1.25
PRICING_OUTPUT[gpt-5.1-codex-max]=10.00
PRICING_CACHE_READ[gpt-5.1-codex-max]=0.125

PRICING_INPUT[gpt-5.1-codex-mini]=0.25
PRICING_OUTPUT[gpt-5.1-codex-mini]=2.00
PRICING_CACHE_READ[gpt-5.1-codex-mini]=0.025

PRICING_INPUT[gpt-5]=1.07
PRICING_OUTPUT[gpt-5]=8.50
PRICING_CACHE_READ[gpt-5]=0.107

PRICING_INPUT[gpt-5-codex]=1.07
PRICING_OUTPUT[gpt-5-codex]=8.50
PRICING_CACHE_READ[gpt-5-codex]=0.107

# Claude models
PRICING_INPUT[claude-opus-4-6]=5.00
PRICING_OUTPUT[claude-opus-4-6]=25.00
PRICING_CACHE_READ[claude-opus-4-6]=0.50
PRICING_CACHE_WRITE[claude-opus-4-6]=6.25

PRICING_INPUT[claude-opus-4-5]=5.00
PRICING_OUTPUT[claude-opus-4-5]=25.00
PRICING_CACHE_READ[claude-opus-4-5]=0.50
PRICING_CACHE_WRITE[claude-opus-4-5]=6.25

PRICING_INPUT[claude-opus-4-1]=15.00
PRICING_OUTPUT[claude-opus-4-1]=75.00
PRICING_CACHE_READ[claude-opus-4-1]=1.50
PRICING_CACHE_WRITE[claude-opus-4-1]=18.75

PRICING_INPUT[claude-sonnet-4-6]=3.00
PRICING_OUTPUT[claude-sonnet-4-6]=15.00
PRICING_CACHE_READ[claude-sonnet-4-6]=0.30
PRICING_CACHE_WRITE[claude-sonnet-4-6]=3.75

PRICING_INPUT[claude-sonnet-4-5]=3.00
PRICING_OUTPUT[claude-sonnet-4-5]=15.00
PRICING_CACHE_READ[claude-sonnet-4-5]=0.30
PRICING_CACHE_WRITE[claude-sonnet-4-5]=3.75

PRICING_INPUT[claude-sonnet-4]=3.00
PRICING_OUTPUT[claude-sonnet-4]=15.00
PRICING_CACHE_READ[claude-sonnet-4]=0.30
PRICING_CACHE_WRITE[claude-sonnet-4]=3.75

PRICING_INPUT[claude-haiku-4-5]=1.00
PRICING_OUTPUT[claude-haiku-4-5]=5.00
PRICING_CACHE_READ[claude-haiku-4-5]=0.10
PRICING_CACHE_WRITE[claude-haiku-4-5]=1.25

PRICING_INPUT[claude-3-5-haiku]=0.80
PRICING_OUTPUT[claude-3-5-haiku]=4.00
PRICING_CACHE_READ[claude-3-5-haiku]=0.08
PRICING_CACHE_WRITE[claude-3-5-haiku]=1.00

# Gemini models
PRICING_INPUT[gemini-3.1-pro]=2.00
PRICING_OUTPUT[gemini-3.1-pro]=12.00
PRICING_CACHE_READ[gemini-3.1-pro]=0.20

PRICING_INPUT[gemini-3-pro]=2.00
PRICING_OUTPUT[gemini-3-pro]=12.00
PRICING_CACHE_READ[gemini-3-pro]=0.20

PRICING_INPUT[gemini-3-flash]=0.50
PRICING_OUTPUT[gemini-3-flash]=3.00
PRICING_CACHE_READ[gemini-3-flash]=0.05

# MiniMax models
PRICING_INPUT[minimax-m2.5]=0.30
PRICING_OUTPUT[minimax-m2.5]=1.20
PRICING_CACHE_READ[minimax-m2.5]=0.06

PRICING_INPUT[minimax-m2.5-free]=0
PRICING_OUTPUT[minimax-m2.5-free]=0
PRICING_CACHE_READ[minimax-m2.5-free]=0

PRICING_INPUT[minimax-m2.1]=0.30
PRICING_OUTPUT[minimax-m2.1]=1.20
PRICING_CACHE_READ[minimax-m2.1]=0.10

# Kimi models
PRICING_INPUT[kimi-k2.5]=0.60
PRICING_OUTPUT[kimi-k2.5]=3.00
PRICING_CACHE_READ[kimi-k2.5]=0.08

PRICING_INPUT[kimi-k2-thinking]=0.40
PRICING_OUTPUT[kimi-k2-thinking]=2.50

PRICING_INPUT[kimi-k2]=0.40
PRICING_OUTPUT[kimi-k2]=2.50

# Qwen models
PRICING_INPUT[qwen3-coder]=0.45
PRICING_OUTPUT[qwen3-coder]=1.50

# Big Pickle (free)
PRICING_INPUT[big-pickle]=0
PRICING_OUTPUT[big-pickle]=0
PRICING_CACHE_READ[big-pickle]=0

usage() {
  cat <<EOF
Usage: opencode-usage.sh [OPTIONS]

Analyze OpenCode token usage and estimate API costs.

Options:
  --by-model      Aggregate by model
  --by-day        Aggregate by date (default)
  --by-project    Aggregate by project directory
  --since DATE    Filter from date (YYYY-MM-DD)
  --until DATE    Filter until date (YYYY-MM-DD)
  --json          Output raw JSON instead of table
  --help          Show this help

Examples:
  opencode-usage.sh
  opencode-usage.sh --by-model
  opencode-usage.sh --by-project --since 2026-02-01
  opencode-usage.sh --by-day --json
EOF
}

calculate_cost() {
  local model="$1"
  local input="$2"
  local output="$3"
  local reasoning="$4"
  local cache_read="$5"
  local cache_write="$6"
  
  local cost=0
  
  if [[ -v "PRICING_INPUT[$model]" ]]; then
    local input_rate="${PRICING_INPUT[$model]:-0}"
    local output_rate="${PRICING_OUTPUT[$model]:-0}"
    local cache_read_rate="${PRICING_CACHE_READ[$model]:-0}"
    local cache_write_rate="${PRICING_CACHE_WRITE[$model]:-0}"
    
    cost=$(echo "scale=4; ($input / 1000000 * $input_rate) + (($output + $reasoning) / 1000000 * $output_rate) + ($cache_read / 1000000 * $cache_read_rate) + ($cache_write / 1000000 * $cache_write_rate)" | bc 2>/dev/null || echo "0")
  fi
  
  echo "$cost"
}

format_tokens() {
  local num="$1"
  if [[ -z "$num" || "$num" == "null" ]]; then
    echo "0"
    return
  fi
  if (( $(echo "$num >= 1000000" | bc -l) )); then
    echo "$(echo "scale=2; $num / 1000000" | bc)M"
  elif (( $(echo "$num >= 1000" | bc -l) )); then
    echo "$(echo "scale=1; $num / 1000" | bc)K"
  else
    echo "$num"
  fi
}

format_cost() {
  local cost="$1"
  printf "\$%.2f" "$cost"
}

# Parse arguments
MODE="by-day"
OUTPUT_FORMAT="table"
SINCE=""
UNTIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --by-model)
      MODE="by-model"
      shift
      ;;
    --by-day)
      MODE="by-day"
      shift
      ;;
    --by-project)
      MODE="by-project"
      shift
      ;;
    --since)
      SINCE="$2"
      shift 2
      ;;
    --until)
      UNTIL="$2"
      shift 2
      ;;
    --json)
      OUTPUT_FORMAT="json"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

# Check if messages directory exists
if [[ ! -d "$MESSAGES_DIR" ]]; then
  echo "No OpenCode messages found at $MESSAGES_DIR" >&2
  exit 1
fi

# Build session ID to project directory mapping
session_projects_json="{}"
if [[ -d "$SESSIONS_DIR" ]]; then
  session_projects_json=$(find "$SESSIONS_DIR" -name "*.json" -exec cat {} \; 2>/dev/null | jq -s '
    map(select(.id != null and .directory != null)) |
    map({(.id): .directory}) |
    add // {}
  ')
fi

# Collect and process all message data
result=$(find "$MESSAGES_DIR" -name "msg_*.json" -exec cat {} \; 2>/dev/null | jq -s --arg mode "$MODE" --arg since "$SINCE" --arg until "$UNTIL" --argjson sessionProjects "$session_projects_json" '
  def since_filter:
    if $since != "" then
      map(select((.time.created // 0) / 1000 >= (($since + "T00:00:00Z") | fromdateiso8601)))
    else . end;
    
  def until_filter:
    if $until != "" then
      map(select((.time.created // 0) / 1000 <= (($until + "T23:59:59Z") | fromdateiso8601)))
    else . end;
  
  map(select(.tokens != null)) |
  since_filter |
  until_filter |
  
  if $mode == "by-model" then
    group_by(.modelID // "unknown") |
    map({
      key: (.[0].modelID // "unknown"),
      value: {
        messages: length,
        input: (map(.tokens.input // 0) | add // 0),
        output: (map(.tokens.output // 0) | add // 0),
        reasoning: (map(.tokens.reasoning // 0) | add // 0),
        cache_read: (map(.tokens.cache.read // 0) | add // 0),
        cache_write: (map(.tokens.cache.write // 0) | add // 0)
      }
    }) |
    sort_by(-(.value.input + .value.output)) |
    from_entries
    
  elif $mode == "by-day" then
    group_by((.time.created // 0) / 1000 | gmtime | strflocaltime("%Y-%m-%d")) |
    map({
      key: (.[0].time.created / 1000 | gmtime | strflocaltime("%Y-%m-%d")),
      value: {
        messages: length,
        input: (map(.tokens.input // 0) | add // 0),
        output: (map(.tokens.output // 0) | add // 0),
        reasoning: (map(.tokens.reasoning // 0) | add // 0),
        cache_read: (map(.tokens.cache.read // 0) | add // 0),
        cache_write: (map(.tokens.cache.write // 0) | add // 0),
        models: (map(.modelID // "unknown") | unique)
      }
    }) |
    sort_by(.key) |
    from_entries
    
  elif $mode == "by-project" then
    map(. + {project: ($sessionProjects[.sessionID // "unknown"] // "unknown")}) |
    group_by(.project) |
    map({
      key: .[0].project,
      value: {
        messages: length,
        input: (map(.tokens.input // 0) | add // 0),
        output: (map(.tokens.output // 0) | add // 0),
        reasoning: (map(.tokens.reasoning // 0) | add // 0),
        cache_read: (map(.tokens.cache.read // 0) | add // 0),
        cache_write: (map(.tokens.cache.write // 0) | add // 0),
        sessions: (map(.sessionID // "unknown") | unique | length)
      }
    }) |
    sort_by(-(.value.input + .value.output)) |
    from_entries
    
  else
    {}
  end
')

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  echo "$result" | jq .
  exit 0
fi

# Calculate totals
totals=$(echo "$result" | jq '{
  messages: ([.[] | .messages // 0] | add // 0),
  input: ([.[] | .input // 0] | add // 0),
  output: ([.[] | .output // 0] | add // 0),
  reasoning: ([.[] | .reasoning // 0] | add // 0),
  cache_read: ([.[] | .cache_read // 0] | add // 0),
  cache_write: ([.[] | .cache_write // 0] | add // 0)
}')

# Output as table
case "$MODE" in
  "by-model")
    echo "MODEL           MESSAGES    INPUT    OUTPUT  REASONING  CACHE_READ  CACHE_WRITE  API_COST"
    echo "─────────────────────────────────────────────────────────────────────────────────────────────"
    
    echo "$result" | jq -r 'to_entries[] | "\(.key)|\(.value.messages)|\(.value.input)|\(.value.output)|\(.value.reasoning)|\(.value.cache_read)|\(.value.cache_write)"' | while IFS='|' read -r model messages input output reasoning cache_read cache_write; do
      cost=$(calculate_cost "$model" "${input:-0}" "${output:-0}" "${reasoning:-0}" "${cache_read:-0}" "${cache_write:-0}")
      
      printf "%-15s %9s %8s %9s %10s %11s %12s %9s\n" \
        "${model:0:15}" \
        "$(printf "%'d" "${messages:-0}")" \
        "$(format_tokens "${input:-0}")" \
        "$(format_tokens "${output:-0}")" \
        "$(format_tokens "${reasoning:-0}")" \
        "$(format_tokens "${cache_read:-0}")" \
        "$(format_tokens "${cache_write:-0}")" \
        "$(format_cost "$cost")"
    done
    
    echo "─────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Calculate total cost from by-model data
    total_cost=$(echo "$result" | jq -r 'to_entries[] | "\(.key)|\(.value.input)|\(.value.output)|\(.value.reasoning)|\(.value.cache_read)|\(.value.cache_write)"' | while IFS='|' read -r model input output reasoning cache_read cache_write; do
      calculate_cost "$model" "${input:-0}" "${output:-0}" "${reasoning:-0}" "${cache_read:-0}" "${cache_write:-0}"
    done | awk '{sum += $1} END {printf "%.2f", sum}')
    
    printf "%-15s %9s %8s %9s %10s %11s %12s %9s\n" \
      "TOTAL" \
      "$(printf "%'d" "$(echo "$totals" | jq -r '.messages')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.input')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.output')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.reasoning')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.cache_read')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.cache_write')")" \
      "\$$total_cost"
    ;;
    
  "by-day")
    echo "DATE        MESSAGES    INPUT    OUTPUT  REASONING  CACHE_READ  API_COST"
    echo "───────────────────────────────────────────────────────────────────────"
    
    echo "$result" | jq -r 'to_entries[] | "\(.key)|\(.value.messages)|\(.value.input)|\(.value.output)|\(.value.reasoning)|\(.value.cache_read)"' | while IFS='|' read -r date messages input output reasoning cache_read; do
      printf "%-10s %9s %8s %9s %10s %11s %9s\n" \
        "$date" \
        "$(printf "%'d" "${messages:-0}")" \
        "$(format_tokens "${input:-0}")" \
        "$(format_tokens "${output:-0}")" \
        "$(format_tokens "${reasoning:-0}")" \
        "$(format_tokens "${cache_read:-0}")" \
        "N/A"
    done
    
    echo "───────────────────────────────────────────────────────────────────────"
    printf "%-10s %9s %8s %9s %10s %11s %9s\n" \
      "TOTAL" \
      "$(printf "%'d" "$(echo "$totals" | jq -r '.messages')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.input')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.output')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.reasoning')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.cache_read')")" \
      "N/A"
    echo ""
    echo "Note: Per-day cost requires model-level breakdown. Use --by-model for costs."
    ;;
    
  "by-project")
    echo "PROJECT                              MESSAGES  SESSIONS    INPUT    OUTPUT  REASONING"
    echo "───────────────────────────────────────────────────────────────────────────────────────"
    
    echo "$result" | jq -r 'to_entries[] | "\(.key)|\(.value.messages)|\(.value.sessions)|\(.value.input)|\(.value.output)|\(.value.reasoning)"' | while IFS='|' read -r project messages sessions input output reasoning; do
      printf "%-36s %9s %9s %8s %9s %10s\n" \
        "${project:0:36}" \
        "$(printf "%'d" "${messages:-0}")" \
        "$(printf "%'d" "${sessions:-0}")" \
        "$(format_tokens "${input:-0}")" \
        "$(format_tokens "${output:-0}")" \
        "$(format_tokens "${reasoning:-0}")"
    done
    
    echo "───────────────────────────────────────────────────────────────────────────────────────"
    printf "%-36s %9s %9s %8s %9s %10s\n" \
      "TOTAL" \
      "$(printf "%'d" "$(echo "$totals" | jq -r '.messages')")" \
      "$(echo "$result" | jq '[.[]?.value.sessions // 0] | add // 0')" \
      "$(format_tokens "$(echo "$totals" | jq -r '.input')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.output')")" \
      "$(format_tokens "$(echo "$totals" | jq -r '.reasoning')")"
    echo ""
    echo "Note: Per-project cost requires model-level breakdown. Use --by-model for costs."
    ;;
esac
