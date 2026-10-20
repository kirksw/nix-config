{
  lib,
  config,
  ...
}:

let
  cfg = config.darwinModules.screenSharing;
  remote = cfg.remoteDesktop;
  primaryUser = config.system.primaryUser;
  asPrimaryUser = command: ''
    launchctl asuser "$(id -u -- ${lib.escapeShellArg primaryUser})" sudo --user=${lib.escapeShellArg primaryUser} -- ${command}
  '';
in
{
  options.darwinModules.screenSharing = {
    enable = lib.mkEnableOption "macOS Screen Sharing, which serves VNC on port 5900";

    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "kisw" ];
      description = ''
        Local users granted Screen Sharing access in addition to the
        administrator group. macOS keeps this access list in the
        com.apple.access_screensharing group, and a non-empty group admits only
        its members. Dropping a name here does not remove the user from the
        group; run
        `sudo dseditgroup -o edit -d <user> -t user com.apple.access_screensharing`
        to revoke it.
      '';
    };

    remoteDesktop = {
      enable = lib.mkEnableOption ''
        remote desktop use of Screen Sharing. macOS sends a black frame while
        the display is asleep, and a locked session cannot be unlocked over
        SSH, so a machine reached from a phone needs both mitigations. Requires
        darwinModules.screenSharing.enable
      '';

      keepDisplayAwake = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Run `caffeinate -d` from a LaunchAgent so the display does not sleep.
          Screen Sharing wakes the display for its own connection, but it sends
          a black frame while the display is off.
        '';
      };

      disableScreenLock = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Never request a password after the screen saver starts or the display
          turns off. A locked session is unreachable from SSH, so a remote
          session can otherwise end at a black screen. This reduces physical
          security: a person with a keyboard on this Mac receives the unlocked
          session.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    system.defaults.screensaver = lib.mkIf (remote.enable && remote.disableScreenLock) {
      askForPassword = false;
      askForPasswordDelay = 0;
    };

    # `caffeinate -d` holds a display-sleep assertion; `-i` alone does not.
    launchd.user.agents.keep-display-awake = lib.mkIf (remote.enable && remote.keepDisplayAwake) {
      serviceConfig = {
        ProgramArguments = [
          "/usr/bin/caffeinate"
          "-d"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
        LimitLoadToSessionType = "Aqua";
      };
    };

    system.activationScripts.postActivation.text = lib.mkAfter ''
      # launchd persists the Screen Sharing enable state outside nix-darwin.
      /bin/launchctl enable system/com.apple.screensharing
      if ! /bin/launchctl print system/com.apple.screensharing >/dev/null 2>&1; then
        /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
      fi

      ${lib.concatMapStrings (user: ''
        if ! /usr/sbin/dseditgroup -o checkmember -m ${lib.escapeShellArg user} com.apple.access_screensharing >/dev/null 2>&1; then
          /usr/sbin/dseditgroup -o edit -a ${lib.escapeShellArg user} -t user com.apple.access_screensharing
        fi
      '') cfg.allowedUsers}

      ${lib.optionalString (remote.enable && remote.disableScreenLock) ''
        # The Lock Screen pane keeps its policy in the per-host (ByHost) domain,
        # which the system.defaults write does not reach.
        ${asPrimaryUser "/usr/bin/defaults -currentHost write com.apple.screensaver askForPassword -int 0"}
        ${asPrimaryUser "/usr/bin/defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 0"}
      ''}
    '';
  };
}
