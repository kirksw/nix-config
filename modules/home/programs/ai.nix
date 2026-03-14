{
  pkgs,
  lib,
  config,
  nixDirectory,
  ...
}:

{
  options = {
    homeModules.aiDev.enable = lib.mkEnableOption "enables ai dev tooling";
  };

  config = lib.mkIf config.homeModules.aiDev.enable {
    home.packages = with pkgs; [
      ollama
    ];
  };
}
