-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local appearance = require("config.appearance")
local group = vim.api.nvim_create_augroup("appearance_sync", { clear = true })
local uv = vim.uv or vim.loop

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  callback = function()
    appearance.apply_theme()
  end,
})

vim.api.nvim_create_autocmd({ "FocusGained", "VimResume" }, {
  group = group,
  callback = function()
    appearance.apply_theme()
  end,
})

local watcher = uv and uv.new_fs_event and uv.new_fs_event() or nil
if watcher then
  local ok = pcall(watcher.start, watcher, appearance.state_dir(), {}, vim.schedule_wrap(function(err, filename)
    if err then
      return
    end

    if filename == nil or filename == "mode" then
      appearance.apply_theme()
    end
  end))

  if ok then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = group,
      once = true,
      callback = function()
        pcall(watcher.stop, watcher)
        pcall(watcher.close, watcher)
      end,
    })
  end
end
