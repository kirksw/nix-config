local M = {}

local state_dir = (vim.env.XDG_STATE_HOME or (vim.env.HOME .. "/.local/state")) .. "/appearance"
local state_file = state_dir .. "/mode"

local function normalize_mode(mode)
  if mode == "light" then
    return "light"
  end

  return "dark"
end

function M.state_dir()
  return state_dir
end

function M.state_file()
  return state_file
end

function M.read_mode()
  local file = io.open(state_file, "r")
  if not file then
    return "dark"
  end

  local mode = file:read("*l")
  file:close()

  return normalize_mode(mode)
end

function M.apply_background()
  local mode = M.read_mode()
  local background = mode == "light" and "light" or "dark"

  vim.g.appearance_sync_mode = mode

  if vim.o.background ~= background then
    vim.o.background = background
  end

  return mode
end

function M.apply_theme(opts)
  local options = opts or {}
  local mode = M.apply_background()
  local current_colorscheme = vim.g.colors_name

  if not options.force and current_colorscheme and not current_colorscheme:match("^rose%-pine") then
    return
  end

  if not options.force and vim.g.appearance_sync_last_applied == mode and current_colorscheme == "rose-pine" then
    return
  end

  vim.g.appearance_sync_last_applied = mode
  pcall(vim.cmd.colorscheme, "rose-pine")
end

return M
