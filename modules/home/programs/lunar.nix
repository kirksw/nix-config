{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.lunar.enable = lib.mkEnableOption "enables lunar tooling";
  };

  config = lib.mkIf config.homeModules.lunar.enable {
    home.packages = with pkgs; [
      # general tooling
      kubeseal
      awscli2

      # internal tooling
      shuttle
      hamctl
      hubble
      dagger
      gitnow
      lunarctl
      cursor-cli
      amp-cli
    ];

    home.sessionVariables = {
      GOPRIVATE = "go.lunarway.com,github.com/lunarway";
    };
  };
}
