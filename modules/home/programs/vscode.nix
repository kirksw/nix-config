
{ pkgs, lib, config, ... }:

{
  options = {
    homeModules.vscode.enable = lib.mkEnableOption "enables vscode";
  };

  config = lib.mkIf config.homeModules.vscode.enable {
    programs.vscode = {
      enable = true;
      profiles.default.extensions = with pkgs.vscode-extensions; [
          vscodevim.vim
          ms-vscode-remote.remote-containers
          jnoortheen.nix-ide
      ];
    };
  };
}
