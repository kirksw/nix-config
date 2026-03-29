{
  pkgs,
  lib,
  config,
  ...
}:

let
  appearanceModeFile = "${config.xdg.stateHome}/appearance/mode";
in
{
  options = {
    homeModules.wezterm.enable = lib.mkEnableOption "enables wezterm";
  };

  config = lib.mkIf config.homeModules.wezterm.enable {
    programs.wezterm = {
      enable = true;
      package = pkgs.wezterm;
      enableZshIntegration = false;

      extraConfig = ''
        local wezterm = require("wezterm")
        local action = wezterm.action
        local config = {}
        local appearance_mode_file = ${builtins.toJSON appearanceModeFile}

        wezterm.add_to_config_reload_watch_list(appearance_mode_file)

        local function read_mode()
          local file = io.open(appearance_mode_file, "r")
          if not file then
            return "dark"
          end

          local mode = file:read("*l")
          file:close()

          if mode == "light" then
            return "light"
          end

          return "dark"
        end

        local function scheme_for_mode(mode)
          if mode == "dark" then
            return "Rosé Pine (Gogh)"
          end

          return "Rosé Pine Dawn (Gogh)"
        end

        config = {
          animation_fps = 120,
          max_fps = 120,
          front_end = "WebGpu",
          webgpu_power_preference = "HighPerformance",
          window_decorations = "RESIZE",
          font = wezterm.font("FiraCode Nerd Font Mono"),
          font_size = 14.0,
          color_scheme = scheme_for_mode(read_mode()),
          window_background_opacity = 0.85,
          macos_window_background_blur = 20,
          window_close_confirmation = 'NeverPrompt',
          window_content_alignment = {
            horizontal = 'Center',
            vertical = 'Center',
          },
          enable_scroll_bar = false,
          window_padding = {
            left = '1cell',
            right = '1cell',
            top = '0.5cell',
            bottom = '0.5cell',
          },
          launch_menu = {},
          hide_tab_bar_if_only_one_tab = true,
          -- Note: use "xxd -psd" to find hex codes for keys
          keys = {
            {
              key = "t",
              mods = "SHIFT|SUPER",
              action = action.Multiple({
                action.SendKey({ key = "a", mods = "CTRL" }),
                action.SendKey({ key = "T" }),
              }),
            },
            {
              key = "k",
              mods = "SHIFT|SUPER",
              action = action.Multiple({
                action.SendKey({ key = "a", mods = "CTRL" }),
                action.SendKey({ key = "K" }),
              }),
            },
            {
              key = "t",
              mods = "CMD",
              action = wezterm.action.DisableDefaultAssignment,
            },
          },
        }

        return config
      '';
    };
  };
}
