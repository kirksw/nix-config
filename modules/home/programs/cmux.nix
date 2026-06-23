{
  lib,
  config,
  ...
}:

{
  options = {
    homeModules.cmux.enable = lib.mkEnableOption "enables cmux config";
  };

  config = lib.mkIf config.homeModules.cmux.enable {
    # No home-manager module for cmux — write the config directly.
    # cmux reads ~/.config/cmux/cmux.json (JSONC).
    xdg.configFile."cmux/cmux.json".text = builtins.toJSON {
      "$schema" = "https://raw.githubusercontent.com/manaflow-ai/cmux/main/web/data/cmux.schema.json";
      schemaVersion = 1;

      # tmux-style prefix bindings (Ctrl+a then key).
      # Existing cmd-based defaults still work alongside these.
      shortcuts.bindings = {
        newSurface = [
          "ctrl+a"
          "c"
        ];
        splitRight = [
          "ctrl+a"
          "shift+5"
        ]; # %
        splitDown = [
          "ctrl+a"
          "shift+'"
        ]; # "
        closeTab = [
          "ctrl+a"
          "x"
        ];
        closeWorkspace = [
          "ctrl+a"
          "shift+7"
        ]; # &
        nextSurface = [
          "ctrl+a"
          "n"
        ];
        prevSurface = [
          "ctrl+a"
          "p"
        ];
        renameTab = [
          "ctrl+a"
          ","
        ];
        renameWorkspace = [
          "ctrl+a"
          "shift+4"
        ]; # $
        focusLeft = [
          "ctrl+a"
          "left"
        ];
        focusRight = [
          "ctrl+a"
          "right"
        ];
        focusUp = [
          "ctrl+a"
          "up"
        ];
        focusDown = [
          "ctrl+a"
          "down"
        ];
        toggleSplitZoom = [
          "ctrl+a"
          "z"
        ];
        toggleTerminalCopyMode = [
          "ctrl+a"
          "["
        ];
        goToWorkspace = [
          "ctrl+a"
          "s"
        ];
        commandPalette = [
          "ctrl+a"
          "shift+;"
        ]; # :
      };
    };
  };
}
