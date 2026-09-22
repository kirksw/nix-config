{
  inputs,
  lib,
  user,
  pkgs,
  ...
}:

let
  homebrewVersion = "7.0.6";
  # Homebrew 7.0.6 provides macOS 27 (Golden Gate) symbols and the cask
  # dependency fix, so this repository carries no Homebrew patches.
  homebrewPackage = pkgs.runCommandLocal "brew-${homebrewVersion}" { version = homebrewVersion; } ''
    cp -R "${inputs.homebrew-brew}" "$out"
  '';
in
{
  homebrew = {
    enable = true;

    global = {
      brewfile = true;
      autoUpdate = true;
    };

    prefix = "/opt/homebrew"; # needed for arm64
    casks = pkgs.callPackage ../casks.nix { };

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
      };
    };

    brews = pkgs.callPackage ../brews.nix { };

    # These app IDs are from using the mas CLI app
    # $ nix shell nixpkgs#mas
    # $ mas search <app name>
    masApps = {
      # "xcode" = 497799835;
    };
  };

  # ponytail: FluidVoice's in-app updater can leave a broken app bundle.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/sudo -u ${user} /usr/bin/defaults write com.FluidApp.app AutoUpdateCheckEnabled -bool false
  '';

  nix-homebrew = {
    inherit user;
    enable = true;
    package = homebrewPackage;
    enableZshIntegration = false;
    autoMigrate = true;
    mutableTaps = false;
  };
}
