{ pkgs, lib, config, ... }:

{
  options = {
    darwinModules.module.enable = lib.mkEnableOption "enables module";
  };

  config = lib.mkIf config.darwinModules.module.enable {
    programs.module = {
      enable = true;
      # other settings here
    };

    home.file = {
      ".config/module" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/<type>/module";
        recursive = true;
      };
    };

    xdg.configFile = {
      "module" = {
        source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/<type>/module";
        recursive = true;
      };
    };
  };
}
