return {
  "alexghergh/nvim-tmux-navigation",
  keys = {
    { "<C-h>", "<cmd>NvimTmuxNavigateLeft<cr>", desc = "tmux navigate left" },
    { "<C-j>", "<cmd>NvimTmuxNavigateDown<cr>", desc = "tmux navigate down" },
    { "<C-k>", "<cmd>NvimTmuxNavigateUp<cr>", desc = "tmux navigate up" },
    { "<C-l>", "<cmd>NvimTmuxNavigateRight<cr>", desc = "tmux navigate right" },
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
