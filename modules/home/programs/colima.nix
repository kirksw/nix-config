{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.colima.enable = lib.mkEnableOption "enables colima tooling";
  };

  config = lib.mkIf config.homeModules.colima.enable {
    home.packages = with pkgs; [
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin colima)
      minikube
      lazydocker
    ];
  };
}
