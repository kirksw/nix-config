{
  lib,
  config,
  ...
}:

{
  options = {
    darwinModules.dock.enable = lib.mkEnableOption "enables dock settings";
  };

  config = lib.mkIf config.darwinModules.dock.enable {
    system.defaults.dock = {
      autohide = true;
      show-recents = false;
      launchanim = true;
      orientation = "left";
      tilesize = 48;
      mru-spaces = false;
    };
  };
}
