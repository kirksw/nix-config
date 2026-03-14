{
  pkgs,
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.qemu.enable = lib.mkEnableOption "enables qemu";
  };

  config = lib.mkIf config.homeModules.qemu.enable {
    home.packages = with pkgs; [
      qemu
      #binfmt
    ];
  };
}
