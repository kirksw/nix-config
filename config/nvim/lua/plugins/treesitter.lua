return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {}, -- Let Nix handle parsers
      auto_install = false,
      highlight = { enable = true }, -- or false if you want to fully disable TS highlighting
    },
  },
}
