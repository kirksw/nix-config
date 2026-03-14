{
  pkgs,
  lib,
  config,
  paths,
  nixDirectory,
  ...
}:

{
  options = {
    homeModules.sketchybar.enable = lib.mkEnableOption "enables sketchybar";
  };

  config = lib.mkIf config.homeModules.sketchybar.enable {
    programs.sketchybar = {
      enable = true;

      extraPackages = with pkgs; [
        sketchybar-app-font
      ];

      #config = {
      #  source = "${self}/config/sketchybar";
      #  recursive = true;
      #};
    };

    xdg.configFile = {
      "sketchybar" = {
        source = paths.mkRepoConfigSymlink {
          inherit config nixDirectory;
          path = "sketchybar";
        };
        recursive = true;
      };
    };
  };
}
