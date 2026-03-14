{
  lib,
  pkgs,
  user,
  self,
  ...
}:

{
  imports = [
    ../../../modules/shared
    ../../../modules/darwin
  ];

  # modules
  darwinModules.aerospace.enable = true;
  darwinModules.dock.enable = true;
  darwinModules.tailscale.enable = true;
  darwinModules.jankyborders.enable = true;

  # specific host config
  nixpkgs.config.allowUnfree = true;

  users.users.${user} = with pkgs; {
    home = "/Users/${user}";
    shell = zsh;
  };

  environment.shells = with pkgs; [
    zsh
  ];
  programs.zsh.enable = true;

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SOPS_AGE_KEY_FILE = "$HOME/.config/age/keys.txt";
  };

  ids.gids.nixbld = 350;

  determinateNix = {
    enable = true;

    determinateNixd = {
      authentication.additionalNetrcSources = [
        "/etc/nix/netrc"
      ];
    };

    customSettings = {
      extra-sandbox-paths = [
        "/etc/nix/netrc"
        "/nix/var/determinate/netrc"
      ];
      trusted-users = [
        "kisw"
        "root"
      ];
      extra-substituters = [
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };
  };

  security = {
    pam.services.sudo_local = {
      enable = true;
      reattach = true;
      touchIdAuth = true;
      watchIdAuth = true;
    };

    sudo = {
      extraConfig = ''
        Defaults  timestamp_timeout=5
      '';
    };
  };

  system = {
    stateVersion = 6;
    primaryUser = "${user}";
    checks.verifyNixPath = false;

    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;
        NSWindowShouldDragOnGesture = true;

        KeyRepeat = 1;
        InitialKeyRepeat = 15; # ~0,25 s

        # Automatically hide and show the menu bar if using sketchybar
        _HIHideMenuBar = false;

        "com.apple.mouse.tapBehavior" = 1;
        "com.apple.sound.beep.volume" = 0.0;
        "com.apple.sound.beep.feedback" = 0;
      };

      finder = {
        AppleShowAllExtensions = true;
        _FXShowPosixPathInTitle = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = false; # true is no bueno
      };

      screencapture.location = "~/Pictures/Screenshots";
      screensaver.askForPasswordDelay = 10; # in seconds
    };

    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };
  };
}
