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
    homeModules.neovim.enable = lib.mkEnableOption "enables neovim";
  };

  config = lib.mkIf config.homeModules.neovim.enable {
    home.packages = with pkgs; [
      neovim-unwrapped
      tree-sitter
      helm-ls
      statix
      nil
      nixfmt
    ];

    home.shellAliases = {
      lv = "nvim";
      vi = "nvim";
      vim = "nvim";
      vimdiff = "nvim -d";
    };

    xdg.configFile = {
      "nvim" = {
        source = paths.mkRepoConfigSymlink {
          inherit config nixDirectory;
          path = "nvim";
        };
      };
    };
  };
}
