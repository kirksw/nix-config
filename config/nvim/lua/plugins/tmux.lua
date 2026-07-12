local function tmux_pane()
  if vim.env.TMUX == nil then
    return nil
  end

  return vim.fn.system({ "tmux", "display-message", "-p", "#{pane_id}" }):gsub("%s+$", "")
end

local function navigate(command, direction)
  return function()
    local before_win = vim.fn.winnr()
    local before_pane = tmux_pane()

    vim.cmd(command)

    if vim.env.HERDR_ENV == nil then
      return
    end

    local same_nvim_win = vim.env.TMUX == nil and before_win == vim.fn.winnr()
    local same_tmux_pane = before_pane ~= nil and before_pane == tmux_pane()

    if same_nvim_win or same_tmux_pane then
      vim.fn.system({ "herdr", "pane", "focus", "--current", "--direction", direction })
    end
  end
end

return {
  "alexghergh/nvim-tmux-navigation",
  keys = {
    { "<C-j>", navigate("NvimTmuxNavigateLeft", "left"), desc = "navigate left" },
    { "<C-k>", navigate("NvimTmuxNavigateDown", "down"), desc = "navigate down" },
    { "<C-l>", navigate("NvimTmuxNavigateUp", "up"), desc = "navigate up" },
    { "<C-;>", navigate("NvimTmuxNavigateRight", "right"), desc = "navigate right" },
    { "<C-:>", navigate("NvimTmuxNavigateRight", "right"), desc = "navigate right" },
    { "<C-\\>", "<cmd>NvimTmuxNavigateLastActive<cr>", desc = "tmux navigate last-active" },
    { "<C-Space>", "<cmd>NvimTmuxNavigateNext<cr>", desc = "tmux navigate next" },
  },
  opts = {
    disable_when_zoomed = false, -- defaults to false
  },
  config = function(_, opts)
    require("nvim-tmux-navigation").setup(opts)
  end,
}
