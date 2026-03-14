{
  lib,
  config,
  ...
}:

{
  options = {
    darwinModules.tailscale.enable = lib.mkEnableOption "enables tailscale mods";
  };

  config = lib.mkIf config.darwinModules.tailscale.enable {
    services.tailscale = {
      enable = true;
    };
  };
}
