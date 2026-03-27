local appearance = require("config.appearance")

return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    init = function()
      appearance.apply_background()
    end,
    opts = {
      variant = "auto",
      dark_variant = "main",
      disable_background = true,
      disable_float_background = true,
      dim_nc_background = false,
    },
    config = function(_, opts)
      require("rose-pine").setup(opts)
      appearance.apply_theme({ force = true })
      vim.opt.cursorline = true
      vim.opt.cursorlineopt = "number"
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "rose-pine",
    },
  },
}
