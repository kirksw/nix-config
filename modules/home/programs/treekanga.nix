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
    homeModules.treekanga.enable = lib.mkEnableOption "enables treekanga";
  };

  config = lib.mkIf config.homeModules.treekanga.enable {
    home.packages = [ pkgs.treekanga ];

    xdg.configFile = {
      "treekanga" = {
        source = paths.mkRepoConfigSymlink {
          inherit config nixDirectory;
          path = "treekanga";
        };
        recursive = true;
      };
    };
  };
}
