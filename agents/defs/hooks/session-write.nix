# Session tracking hooks: write JSON session files on start/end.
# Usage: import this file as a function receiving pkgs, then merge into your module list.
# Example (in flake.nix or preset):
#   modules = defaultModules ++ [ (import ./defs/hooks/session-write.nix { inherit pkgs; }) ];
{ pkgs }:
let
  sessionThreadSync = pkgs.writeText "session-thread-sync.py" (
    builtins.readFile ./session-thread-sync.py
  );
  sessionThreadContext = pkgs.writeText "session-thread-context.py" (
    builtins.readFile ./session-thread-context.py
  );
in
{
  hooks = [
    {
      event = "session-start";
      package = pkgs.symlinkJoin {
        name = "nix-agents-session-start-tools";
        paths = [
          pkgs.jq
          pkgs.python3
        ];
      };
      command = ''
        SESSION_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/sessions/''${NAX_PROFILE:-default}/$(basename "$PWD")"
        mkdir -p "$SESSION_DIR"
        SESSION_FILE="$SESSION_DIR/$(date -u +%Y-%m-%dT%H-%M-%S).json"
        SESSION_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "$(date +%s)-$$")"
        SKILL_VERSIONS="$(cat "''${NAX_SKILL_VERSIONS:-/dev/null}" 2>/dev/null || echo '{}')"
        jq -n \
          --arg id "$SESSION_ID" \
          --arg profile "''${NAX_PROFILE:-default}" \
          --arg project "$PWD" \
          --arg ts "$(date -u +%FT%TZ)" \
          --argjson skillVersions "$SKILL_VERSIONS" \
          '{
            version: 1,
            sessionId: $id,
            profile: $profile,
            project: $project,
            startedAt: $ts,
            endedAt: null,
            branch: null,
            lastCommit: null,
            durationSec: null,
            tokenUsage: null,
            skillVersions: $skillVersions,
            accomplished: [],
            incomplete: [],
            events: []
          }' > "$SESSION_FILE"
        _NAX_STATE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
        mkdir -p "$_NAX_STATE_DIR"
        echo "$SESSION_FILE" > "$_NAX_STATE_DIR/current-session"
        echo "$SESSION_ID" > "$_NAX_STATE_DIR/session-id"

        # Thread OS context injection: resolve the thread for this project
        # and write open blockers, recent decisions, and last session's
        # incomplete items into the session JSON and THREAD_CONTEXT.md.
        THREAD_OS_SESSION_FILE="$SESSION_FILE" \
        python3 ${sessionThreadContext} \
          || echo "thread-os: context injection failed (non-fatal)" >&2
      '';
    }
    {
      event = "session-end";
      package = pkgs.symlinkJoin {
        name = "nix-agents-session-end-tools";
        paths = [
          pkgs.jq
          pkgs.python3
        ];
      };
      command = ''
        SESSION_FILE="$(cat "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}/current-session" 2>/dev/null)"
        if [ -z "$SESSION_FILE" ] || [ ! -f "$SESSION_FILE" ]; then exit 0; fi
        EVENT_FILE="$(mktemp 2>/dev/null || echo "$SESSION_FILE.event")"
        cat > "$EVENT_FILE" 2>/dev/null || true
        BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
        COMMIT="$(git rev-parse --short HEAD 2>/dev/null)"
        STARTED="$(jq -r .startedAt "$SESSION_FILE")"
        START_EPOCH="$(date -d "$STARTED" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$STARTED" +%s 2>/dev/null || echo 0)"
        DURATION="$(( $(date +%s) - START_EPOCH ))"
        jq \
          --arg end "$(date -u +%FT%TZ)" \
          --arg branch "$BRANCH" \
          --arg commit "$COMMIT" \
          --argjson dur "$DURATION" \
          '.endedAt = $end | .branch = $branch | .lastCommit = $commit | .durationSec = $dur' \
          "$SESSION_FILE" > "$SESSION_FILE.tmp" && mv "$SESSION_FILE.tmp" "$SESSION_FILE"

        # Thread OS session sync: bridges session activity to the JSONL store.
        # Writes session records, extracts decisions/blockers, updates thread state.
        THREAD_OS_EVENT_FILE="$EVENT_FILE" \
        THREAD_OS_SESSION_FILE="$SESSION_FILE" \
        python3 ${sessionThreadSync} \
          || echo "thread-os: session sync failed (non-fatal)" >&2

        rm -f "$EVENT_FILE"
        rm -rf "''${XDG_DATA_HOME:-$HOME/.local/share}/nix-agents/state/''${NAX_WRAPPER_PID:-$$}"
      '';
    }
  ];
}
