{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.wezterm.enable = lib.mkEnableOption "enables wezterm";
  };

  config = lib.mkIf config.homeModules.wezterm.enable {
    programs.wezterm = {
      enable = true;
      package = pkgs.wezterm;
      enableZshIntegration = false;
      extraConfig = builtins.readFile ../../../config/wezterm/wezterm.lua;
    };
  };
}
