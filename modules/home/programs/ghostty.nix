{
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.ghostty.enable = lib.mkEnableOption "enables ghostty";
  };

  config = lib.mkIf config.homeModules.ghostty.enable {
    programs.ghostty = {
      enable = true;
      package = null; # package = inputs.ghostty.packages.${pkgs.system}.default;
      enableZshIntegration = true;
      #clearDefaultKeybinds = true;
      # NOTE: these can only be used on linux
      # installVimSyntax = true;
      # installBatSyntax = true;
      settings = {
        keybind = [
          "unconsumed:ctrl+enter=toggle_fullscreen"
          "cmd+ctrl+r=reload_config"
          "global:cmd+ctrl+o=toggle_quick_terminal"
        ];
        theme = "light:Rose Pine Dawn,dark:Rose Pine";
        font-size = 14;
        font-family = "FiraCode Nerd Font Mono";
        font-thicken = true;
        font-style = "Regular";
        macos-titlebar-style = "hidden";
        quit-after-last-window-closed = true;
        window-padding-x = 10;
        window-padding-y = 10;
        window-padding-balance = true;
        confirm-close-surface = false;
        cursor-style = "block";
        cursor-style-blink = false;
        unfocused-split-opacity = 0.6;
        background-opacity = 0.8;
        background-blur = true;
        background-blur-radius = 20;
        quick-terminal-position = "center";
        quick-terminal-animation-duration = 0;
        quick-terminal-autohide = false;
        font-feature = [
          "-liga"
          "-dlig"
          "-calt"
        ];
      };
    };
  };
}
