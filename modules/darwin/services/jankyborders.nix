{
  lib,
  config,
  ...
}:

{
  options = {
    darwinModules.jankyborders.enable = lib.mkEnableOption "enables jankyborders";
  };

  config = lib.mkIf config.darwinModules.jankyborders.enable {
    services.jankyborders = {
      enable = true;
      width = 8.0;
      hidpi = true;
      active_color = "0xFFFFFF";
      inactive_color = "0xCCCCCC";
    };
  };
}
