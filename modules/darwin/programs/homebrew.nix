{
  inputs,
  user,
  pkgs,
  ...
}:

let
  homebrewVersion = "5.1.9";
  homebrewPackage = pkgs.runCommandLocal "brew-${homebrewVersion}" { version = homebrewVersion; } ''
    cp -R "${inputs.homebrew-brew}" "$out"
    chmod -R u+w "$out/Library/Homebrew/api/cask"
    # The cask API can encode bare macOS dependencies as {}, which otherwise trips dep_type.to_sym.
    substituteInPlace "$out/Library/Homebrew/api/cask/cask_struct_generator.rb" \
      --replace-fail 'dep_type = value.keys.first' $'dep_type = value.keys.first\n            next [key, nil] if dep_type.nil?'
  '';
  openWisprTap = pkgs.runCommandLocal "homebrew-open-wispr" { } ''
    cp -R "${inputs.open-wispr-tap}" "$out"
    chmod -R u+w "$out"
    # The upstream hook writes outside Homebrew's sandbox and makes brew bundle fail.
    sed -i '/^  def post_install$/,/^  end$/d' "$out/open-wispr.rb"
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
    taps = [ "human37/open-wispr" ];
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

  nix-homebrew = {
    inherit user;
    enable = true;
    package = homebrewPackage;
    enableZshIntegration = false;
    autoMigrate = true;
    mutableTaps = false;
    taps = {
      "human37/homebrew-open-wispr" = openWisprTap;
    };
  };
}
