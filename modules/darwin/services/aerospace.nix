{
  self,
  lib,
  config,
  ...
}:

{
  options = {
    darwinModules.aerospace.enable = lib.mkEnableOption "enables aerospace tiling wm";
  };

  config = lib.mkIf config.darwinModules.aerospace.enable {
    services.aerospace = {
      enable = true;
      settings = {
        start-at-login = false;
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;
        accordion-padding = 50;
        default-root-container-layout = "tiles";
        default-root-container-orientation = "auto";
        on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
        automatically-unhide-macos-hidden-apps = true;
        key-mapping = {
          preset = "qwerty";
        };
        gaps = {
          outer.left = 4;
          outer.bottom = 4;
          outer.top = 4;
          outer.right = 4;
          inner.horizontal = 4;
          inner.vertical = 4;
        };
        mode.main.binding = {
          alt-ctrl-shift-f = "fullscreen";
          alt-ctrl-f = "layout floating";

          alt-slash = "layout tiles horizontal vertical";
          alt-comma = "layout accordion horizontal vertical";

          alt-q = "close";

          alt-h = "focus left";
          alt-j = "focus down";
          alt-k = "focus up";
          alt-l = "focus right";

          alt-shift-h = "move left";
          alt-shift-j = "move down";
          alt-shift-k = "move up";
          alt-shift-l = "move right";

          alt-shift-minus = "resize smart -50";
          alt-shift-equal = "resize smart +50";

          alt-1 = "workspace 1";
          alt-2 = "workspace 2";
          alt-3 = "workspace 3";
          alt-4 = "workspace 4";
          alt-5 = "workspace 5";
          alt-6 = "workspace 6";
          alt-7 = "workspace 7";
          alt-8 = "workspace 8";
          alt-9 = "workspace 9";

          alt-shift-1 = "move-node-to-workspace 1";
          alt-shift-2 = "move-node-to-workspace 2";
          alt-shift-3 = "move-node-to-workspace 3";
          alt-shift-4 = "move-node-to-workspace 4";
          alt-shift-5 = "move-node-to-workspace 5";

          alt-tab = "workspace-back-and-forth";
          alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
          alt-shift-semicolon = "mode service";

          alt-shift-s = "exec-and-forget open -a /Applications/Slack.app";
          alt-shift-g = "exec-and-forget open -na ghostty";
          alt-shift-a = "exec-and-forget ${self}/config/aerospace/raycast-ai.sh";
          alt-shift-n = "exec-and-forget ${self}/config/aerospace/popup-notes.sh";
          alt-shift-c = "exec-and-forget ${self}/config/aerospace/popup-ai.sh";
        };
        mode.service.binding = {
          esc = [
            "reload-config"
            "mode main"
          ];
          r = [
            "flatten-workspace-tree"
            "mode main"
          ];
          f = [
            "layout floating tiling"
            "mode main"
          ];
          backspace = [
            "close-all-windows-but-current"
            "mode main"
          ];
          alt-shift-h = [
            "join-with left"
            "mode main"
          ];
          alt-shift-j = [
            "join-with down"
            "mode main"
          ];
          alt-shift-k = [
            "join-with up"
            "mode main"
          ];
          alt-shift-l = [
            "join-with right"
            "mode main"
          ];
        };
      };
    };
  };
}
