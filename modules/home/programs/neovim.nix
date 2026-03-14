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
    programs.neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;
      vimdiffAlias = true;
      withRuby = false;
      withNodeJs = false;
      withPython3 = false;

      plugins = with pkgs; [
        vimPlugins.nvim-treesitter.withAllGrammars
      ];

      extraPackages = with pkgs; [
        tree-sitter
        helm-ls
        statix
        nil
        nixfmt
      ];
    };

    home.shellAliases = {
      lv = "nvim";
    };

    xdg.configFile = {
      "nvim" = {
        source = paths.mkRepoConfigSymlink {
          inherit config nixDirectory;
          path = "nvim";
        };
        recursive = true;
      };
    };
  };
}
