{
  pkgs,
  lib,
  config,
  ...
}:

let
  stateDir = "${config.xdg.stateHome}/appearance";
  stateFile = "${stateDir}/mode";
  syncScript = pkgs.writeShellScript "appearance-sync" ''
    set -eu

    readonly state_dir=${lib.escapeShellArg stateDir}
    readonly state_file=${lib.escapeShellArg stateFile}
    readonly tmux_bin=${lib.escapeShellArg "${pkgs.tmux}/bin/tmux"}
    readonly rose_pine_tmux=${lib.escapeShellArg "${pkgs.tmuxPlugins.rose-pine}/share/tmux-plugins/rose-pine/rose-pine.tmux"}

    read_mode() {
      if /usr/bin/defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
        printf 'dark\n'
      else
        printf 'light\n'
      fi
    }

    apply_mode() {
      local mode
      mode="$(read_mode)"

      /bin/mkdir -p "$state_dir"
      printf '%s\n' "$mode" > "$state_file"

      if "$tmux_bin" ls >/dev/null 2>&1; then
        "$tmux_bin" run-shell "$rose_pine_tmux" >/dev/null 2>&1 || true
        "$tmux_bin" refresh-client -S >/dev/null 2>&1 || true
      fi
    }

    apply_mode

    while ${pkgs.dark-mode-notify}/bin/dark-mode-notify; do
      apply_mode
    done
  '';
in
{
  options = {
    homeModules.appearanceSync.enable = lib.mkEnableOption "syncs tmux and neovim with macOS appearance";
  };

  config = lib.mkIf (config.homeModules.appearanceSync.enable && pkgs.stdenv.isDarwin) {
    home.activation.appearanceSyncState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p ${lib.escapeShellArg stateDir}
      /usr/bin/defaults delete -g AppleInterfaceStyle >/dev/null 2>&1 || true
    '';

    launchd.agents.appearance-sync = {
      enable = true;
      config = {
        Program = syncScript;
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/appearance-sync.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/appearance-sync.err.log";
      };
    };
  };
}
