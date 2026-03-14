{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.communication.enable = lib.mkEnableOption "enables communication tooling";
  };

  config = lib.mkIf config.homeModules.communication.enable {
    home.packages = with pkgs; [
      whatsapp-for-mac
      discord
    ];
  };
}
