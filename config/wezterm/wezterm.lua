local action = wezterm.action
local config = {}

local function get_macos_mode()
  -- Query macOS preferences directly — more reliable than window:get_appearance()
  -- on newer macOS versions. Key absent = light mode, "Dark" = dark mode.
  local _, stdout, _ = wezterm.run_child_process({ "defaults", "read", "-g", "AppleInterfaceStyle" })
  if stdout and stdout:find("Dark") then
    return "dark"
  end
  return "light"
end

local function scheme_for_mode(mode)
  if mode == "dark" then
    return "rose-pine-sync-dark"
  end

  return "rose-pine-sync-light"
end

local function opacity_for_mode(mode)
  if mode == "dark" then
    return 0.85
  end

  return 0.97
end

local function apply_mode(window, mode)
  local overrides = window:get_config_overrides() or {}
  local scheme = scheme_for_mode(mode)
  local opacity = opacity_for_mode(mode)
  local dirty = false

  if overrides.color_scheme ~= scheme then
    overrides.color_scheme = scheme
    dirty = true
  end

  if overrides.window_background_opacity ~= opacity then
    overrides.window_background_opacity = opacity
    dirty = true
  end

  if dirty then
    window:set_config_overrides(overrides)
  end
end

wezterm.on("window-config-reloaded", function(window, _)
  apply_mode(window, get_macos_mode())
end)

wezterm.on("update-status", function(window, _)
  apply_mode(window, get_macos_mode())
end)

local initial_mode = get_macos_mode()

config = {
  animation_fps = 120,
  max_fps = 120,
  front_end = "WebGpu",
  webgpu_power_preference = "HighPerformance",
  window_decorations = "RESIZE",
  font = wezterm.font("FiraCode Nerd Font Mono"),
  font_size = 14.0,
  color_schemes = {
    ["rose-pine-sync-dark"] = {
      foreground = "#e0def4",
      background = "#191724",
      cursor_bg = "#ebbcba",
      cursor_fg = "#191724",
      cursor_border = "#ebbcba",
      selection_bg = "#403d52",
      selection_fg = "#e0def4",
      ansi = {
        "#26233a",
        "#eb6f92",
        "#31748f",
        "#f6c177",
        "#9ccfd8",
        "#c4a7e7",
        "#ebbcba",
        "#e0def4",
      },
      brights = {
        "#6e6a86",
        "#eb6f92",
        "#31748f",
        "#f6c177",
        "#9ccfd8",
        "#c4a7e7",
        "#ebbcba",
        "#e0def4",
      },
      tab_bar = {
        background = "#191724",
        active_tab = {
          bg_color = "#1f1d2e",
          fg_color = "#e0def4",
        },
        inactive_tab = {
          bg_color = "#191724",
          fg_color = "#908caa",
        },
        inactive_tab_hover = {
          bg_color = "#1f1d2e",
          fg_color = "#e0def4",
        },
        new_tab = {
          bg_color = "#191724",
          fg_color = "#908caa",
        },
        new_tab_hover = {
          bg_color = "#1f1d2e",
          fg_color = "#e0def4",
        },
      },
    },
    ["rose-pine-sync-light"] = {
      foreground = "#575279",
      background = "#faf4ed",
      cursor_bg = "#d7827e",
      cursor_fg = "#faf4ed",
      cursor_border = "#d7827e",
      selection_bg = "#dfdad9",
      selection_fg = "#575279",
      ansi = {
        "#f2e9e1",
        "#b4367a",
        "#286983",
        "#ea9d34",
        "#56949f",
        "#907aa9",
        "#d7827e",
        "#575279",
      },
      brights = {
        "#9893a5",
        "#b4367a",
        "#286983",
        "#ea9d34",
        "#56949f",
        "#907aa9",
        "#d7827e",
        "#575279",
      },
      tab_bar = {
        background = "#faf4ed",
        active_tab = {
          bg_color = "#fffaf3",
          fg_color = "#575279",
        },
        inactive_tab = {
          bg_color = "#faf4ed",
          fg_color = "#797593",
        },
        inactive_tab_hover = {
          bg_color = "#fffaf3",
          fg_color = "#575279",
        },
        new_tab = {
          bg_color = "#faf4ed",
          fg_color = "#797593",
        },
        new_tab_hover = {
          bg_color = "#fffaf3",
          fg_color = "#575279",
        },
      },
    },
  },
  color_scheme = scheme_for_mode(initial_mode),
  window_background_opacity = opacity_for_mode(initial_mode),
  macos_window_background_blur = 20,
  window_close_confirmation = "NeverPrompt",
  status_update_interval = 1000,
  window_content_alignment = {
    horizontal = "Center",
    vertical = "Center",
  },
  enable_scroll_bar = false,
  window_padding = {
    left = "1cell",
    right = "1cell",
    top = "0.5cell",
    bottom = "0.5cell",
  },
  launch_menu = {},
  hide_tab_bar_if_only_one_tab = false,
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
