{ pkgs, lib, config, ... }:

{
  options = {
    homeModules.youtube.enable = lib.mkEnableOption "enables module";
  };

  config = lib.mkIf config.homeModules.youtube.enable {
    home.packages = with pkgs; [
      yt-dlp
      # mpv
      # ytui_music
    ];
  };
}
