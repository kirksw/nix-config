{
  self,
  pkgs,
  lib,
  config,
  ...
}:

let
  aerospaceApp = "/Applications/Nix Apps/AeroSpace.app";
  aerospaceServer = "${aerospaceApp}/Contents/MacOS/AeroSpace";
  aerospaceClient = "${pkgs.aerospace}/bin/aerospace";
  aerospaceSettings = {
    start-at-login = false;
    enable-normalization-flatten-containers = true;
    enable-normalization-opposite-orientation-for-nested-containers = true;
    accordion-padding = 50;
    default-root-container-layout = "tiles";
    default-root-container-orientation = "auto";
    on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
    automatically-unhide-macos-hidden-apps = true;
    key-mapping = {
      preset = "qwerty";
    };
    gaps = {
      outer.left = 4;
      outer.bottom = 4;
      outer.top = 4;
      outer.right = 4;
      inner.horizontal = 4;
      inner.vertical = 4;
    };
    mode.main.binding = {
      alt-ctrl-shift-f = "fullscreen";
      alt-ctrl-f = "layout floating";

      alt-slash = "layout tiles horizontal vertical";
      alt-comma = "layout accordion horizontal vertical";

      alt-q = "close";

      alt-h = "focus left";
      alt-j = "focus down";
      alt-k = "focus up";
      alt-l = "focus right";

      alt-shift-h = "move left";
      alt-shift-j = "move down";
      alt-shift-k = "move up";
      alt-shift-l = "move right";

      alt-shift-minus = "resize smart -50";
      alt-shift-equal = "resize smart +50";

      alt-1 = "workspace 1";
      alt-2 = "workspace 2";
      alt-3 = "workspace 3";
      alt-4 = "workspace 4";
      alt-5 = "workspace 5";
      alt-6 = "workspace 6";
      alt-7 = "workspace 7";
      alt-8 = "workspace 8";
      alt-9 = "workspace 9";
      alt-0 = "workspace 10";

      alt-shift-1 = "move-node-to-workspace 1";
      alt-shift-2 = "move-node-to-workspace 2";
      alt-shift-3 = "move-node-to-workspace 3";
      alt-shift-4 = "move-node-to-workspace 4";
      alt-shift-5 = "move-node-to-workspace 5";
      alt-shift-6 = "move-node-to-workspace 6";
      alt-shift-7 = "move-node-to-workspace 7";
      alt-shift-8 = "move-node-to-workspace 8";
      alt-shift-9 = "move-node-to-workspace 9";
      alt-shift-0 = "move-node-to-workspace 10";

      alt-tab = "workspace-back-and-forth";
      alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
      alt-shift-semicolon = "mode service";

      alt-shift-s = "exec-and-forget open -a /Applications/Slack.app";
      alt-shift-g = "exec-and-forget open -na ghostty";
      alt-shift-a = "exec-and-forget ${self}/config/aerospace/raycast-ai.sh";
      alt-shift-n = "exec-and-forget ${self}/config/aerospace/popup-notes.sh";
      alt-shift-c = "exec-and-forget ${self}/config/aerospace/popup-ai.sh";
    };
    mode.service.binding = {
      esc = [
        "reload-config"
        "mode main"
      ];
      r = [
        "flatten-workspace-tree"
        "mode main"
      ];
      f = [
        "layout floating tiling"
        "mode main"
      ];
      backspace = [
        "close-all-windows-but-current"
        "mode main"
      ];
      alt-shift-h = [
        "join-with left"
        "mode main"
      ];
      alt-shift-j = [
        "join-with down"
        "mode main"
      ];
      alt-shift-k = [
        "join-with up"
        "mode main"
      ];
      alt-shift-l = [
        "join-with right"
        "mode main"
      ];
    };
  };
  aerospaceConfig = (pkgs.formats.toml { }).generate "aerospace.toml" aerospaceSettings;
  primaryUser = config.system.primaryUser;
  userHome = config.users.users.${primaryUser}.home or "/Users/${primaryUser}";
  stateDir = "${userHome}/.cache/aerospace-switch-state";
  launchAgentLabel = "${config.launchd.labelPrefix}.aerospace";
  shellPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gnugrep
  ];
  asPrimaryUser = command: ''
    launchctl asuser "$(id -u -- ${lib.escapeShellArg primaryUser})" sudo --user=${lib.escapeShellArg primaryUser} -- ${command}
  '';
  captureAerospaceState = pkgs.writeShellScript "capture-aerospace-state" ''
    set -eu

    export PATH="${shellPath}:/usr/bin:/bin"

    state_dir=${lib.escapeShellArg stateDir}
    aerospace=${lib.escapeShellArg aerospaceClient}
    marker="$state_dir/restore-needed"
    error_log="$state_dir/capture-error.log"

    mkdir -p "$state_dir"

    echo "AeroSpace: saving window state before switch" >&2

    if ! "$aerospace" list-workspaces --all > "$state_dir/workspace-probe.tmp" 2> "$error_log"; then
      echo "AeroSpace: skipped save; CLI cannot reach server: $(head -n 1 "$error_log")" >&2
      rm -f "$marker"
      rm -f "$state_dir/workspace-probe.tmp"
      exit 0
    fi
    rm -f "$state_dir/workspace-probe.tmp"

    if "$aerospace" list-windows --all --format "%{window-id}%{tab}%{workspace}%{tab}%{window-layout}%{tab}%{window-is-fullscreen}" > "$state_dir/windows.tsv.tmp" 2> "$error_log"; then
      mv "$state_dir/windows.tsv.tmp" "$state_dir/windows.tsv"
    else
      echo "AeroSpace: skipped save; failed to list windows: $(head -n 1 "$error_log")" >&2
      rm -f "$state_dir/windows.tsv.tmp" "$marker"
      exit 0
    fi

    "$aerospace" list-workspaces --focused --format "%{workspace}" > "$state_dir/focused-workspace.tmp" 2>/dev/null \
      && mv "$state_dir/focused-workspace.tmp" "$state_dir/focused-workspace" \
      || rm -f "$state_dir/focused-workspace.tmp" "$state_dir/focused-workspace"

    "$aerospace" list-workspaces --all --format "%{workspace}%{tab}%{monitor-id}%{tab}%{workspace-is-visible}" > "$state_dir/workspaces.tsv.tmp" 2>/dev/null \
      && mv "$state_dir/workspaces.tsv.tmp" "$state_dir/workspaces.tsv" \
      || rm -f "$state_dir/workspaces.tsv.tmp" "$state_dir/workspaces.tsv"

    "$aerospace" list-windows --focused --format "%{window-id}" > "$state_dir/focused-window.tmp" 2>/dev/null \
      && mv "$state_dir/focused-window.tmp" "$state_dir/focused-window" \
      || rm -f "$state_dir/focused-window.tmp" "$state_dir/focused-window"

    touch "$marker"
    echo "AeroSpace: saved $(wc -l < "$state_dir/windows.tsv" | tr -d ' ') windows for restore" >&2
  '';
  restoreAerospaceState = pkgs.writeShellScript "restore-aerospace-state" ''
    set -eu

    export PATH="${shellPath}:/usr/bin:/bin"

    state_dir=${lib.escapeShellArg stateDir}
    aerospace=${lib.escapeShellArg aerospaceClient}
    launch_agent=${lib.escapeShellArg launchAgentLabel}
    marker="$state_dir/restore-needed"
    windows="$state_dir/windows.tsv"
    workspaces="$state_dir/workspaces.tsv"
    current_windows="$state_dir/current-windows"

    [ -f "$marker" ] || exit 0

    echo "AeroSpace: restoring window state after switch" >&2

    launchctl kickstart -k "gui/$(id -u)/$launch_agent" >/dev/null 2>&1 || true

    attempts=0
    until "$aerospace" list-workspaces --all >/dev/null 2>&1; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 60 ]; then
        echo "AeroSpace: restore deferred; CLI cannot reach server after 60s" >&2
        exit 0
      fi
      sleep 1
    done

    attempts=0
    until "$aerospace" list-windows --all --format "%{window-id}" > "$current_windows" 2>/dev/null && [ -s "$current_windows" ]; do
      attempts=$((attempts + 1))
      if [ "$attempts" -ge 10 ]; then
        : > "$current_windows"
        break
      fi
      sleep 1
    done

    window_exists() {
      [ -s "$current_windows" ] && grep -Fxq -- "$1" "$current_windows"
    }

    if [ -s "$windows" ]; then
      while IFS="$(printf '\t')" read -r window_id workspace layout fullscreen; do
        [ -n "$window_id" ] || continue
        window_exists "$window_id" || continue
        [ -n "$workspace" ] && "$aerospace" move-node-to-workspace "$workspace" --window-id "$window_id" >/dev/null 2>&1 || true
      done < "$windows"

      while IFS="$(printf '\t')" read -r window_id workspace layout fullscreen; do
        [ -n "$window_id" ] || continue
        window_exists "$window_id" || continue

        case "$layout" in
          floating|h_tiles|v_tiles|h_accordion|v_accordion)
            "$aerospace" layout "$layout" --window-id "$window_id" >/dev/null 2>&1 || true
            ;;
        esac

        case "$fullscreen" in
          true)
            "$aerospace" fullscreen on --window-id "$window_id" >/dev/null 2>&1 || true
            ;;
          false)
            "$aerospace" fullscreen off --window-id "$window_id" >/dev/null 2>&1 || true
            ;;
        esac
      done < "$windows"
    fi

    if [ -s "$workspaces" ]; then
      while IFS="$(printf '\t')" read -r workspace monitor_id visible; do
        [ "$visible" = true ] || continue
        [ -n "$workspace" ] || continue
        [ -n "$monitor_id" ] || continue
        "$aerospace" workspace "$workspace" >/dev/null 2>&1 || true
        "$aerospace" move-workspace-to-monitor "$monitor_id" >/dev/null 2>&1 || true
      done < "$workspaces"
    fi

    if [ -s "$state_dir/focused-workspace" ]; then
      focused_workspace="$(head -n 1 "$state_dir/focused-workspace")"
      [ -n "$focused_workspace" ] && "$aerospace" workspace "$focused_workspace" >/dev/null 2>&1 || true
    fi

    if [ -s "$state_dir/focused-window" ]; then
      focused_window="$(head -n 1 "$state_dir/focused-window")"
      [ -n "$focused_window" ] && "$aerospace" focus --window-id "$focused_window" >/dev/null 2>&1 || true
    fi

    "$aerospace" move-mouse window-lazy-center >/dev/null 2>&1 || "$aerospace" move-mouse monitor-lazy-center >/dev/null 2>&1 || true

    rm -f "$marker" "$current_windows"
    echo "AeroSpace: restore complete" >&2
  '';
in

{
  options = {
    darwinModules.aerospace.enable = lib.mkEnableOption "enables aerospace tiling wm";
  };

  config = lib.mkIf config.darwinModules.aerospace.enable {
    system.activationScripts.preActivation.text = lib.mkBefore ''
      ${asPrimaryUser captureAerospaceState}
    '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      if [ -f ${lib.escapeShellArg stateDir}/restore-needed ]; then
        ${asPrimaryUser restoreAerospaceState}
      else
        echo "AeroSpace: no saved switch state to restore" >&2
      fi
    '';

    environment.systemPackages = [
      pkgs.aerospace
    ];

    launchd.user.agents.aerospace = {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path ${lib.escapeShellArg aerospaceApp} && exec ${lib.escapeShellArg aerospaceServer} --config-path ${lib.escapeShellArg aerospaceConfig}"
        ];
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Interactive";
      };
    };
  };
}
