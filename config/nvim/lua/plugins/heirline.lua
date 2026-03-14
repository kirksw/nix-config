return {
  {
    "akinsho/bufferline.nvim",
    enabled = false,
  },
  {
    "nvim-lualine/lualine.nvim",
    enabled = false,
  },
  {
    "rebelot/heirline.nvim",
    dependencies = {
      "zeioth/heirline-components.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    event = "VeryLazy",
    config = function()
      local heirline = require("heirline")
      local lib = require("heirline-components.all")
      local conditions = require("heirline.conditions")
      local utils = require("heirline.utils")

      -- Setup
      lib.init.subscribe_to_events()
      heirline.load_colors(lib.hl.get_colors())

      -- Config
      heirline.setup({
        tabline = {
          lib.component.tabline_conditional_padding(),
          lib.component.tabline_buffers(),
          lib.component.tabline_tabpages(),
        },
        --winbar = { -- UI breadcrumbs bar
        --  init = function(self)
        --    self.bufnr = vim.api.nvim_get_current_buf()
        --  end,
        --  fallthrough = false,
        --  -- Winbar for terminal, neotree, and aerial.
        --  {
        --    condition = function()
        --      return not lib.condition.is_active()
        --    end,
        --    {
        --      lib.component.neotree(),
        --      lib.component.compiler_play(),
        --      lib.component.fill(),
        --      lib.component.compiler_build_type(),
        --      lib.component.compiler_redo(),
        --      lib.component.aerial(),
        --    },
        --  },
        --  -- Regular winbar
        --  {
        --    lib.component.neotree(),
        --    lib.component.compiler_play(),
        --    lib.component.fill(),
        --    lib.component.breadcrumbs(),
        --    lib.component.fill(),
        --    lib.component.compiler_redo(),
        --    lib.component.aerial(),
        --  },
        --},
        statusline = {
          hl = { fg = "fg", bg = "bg" },
          lib.component.mode(),
          lib.component.git_branch(),
          lib.component.file_info(),
          lib.component.git_diff(),
          lib.component.diagnostics(),
          lib.component.fill(),
          lib.component.lsp(),
          lib.component.nav(),
          lib.component.mode({ surround = { separator = "right" } }),
        },
        --opts = {
        --  -- if the callback returns true, the winbar will be disabled for that window
        --  -- the args parameter corresponds to the table argument passed to autocommand callbacks. :h nvim_lua_create_autocmd()
        --  disable_winbar_cb = function(args)
        --    return conditions.buffer_matches({
        --      buftype = { "nofile", "prompt", "help", "quickfix" },
        --      filetype = { "^git.*", "fugitive", "Trouble", "dashboard", "mini.files" },
        --    }, args.buf)
        --  end,
        --},
      })

      vim.o.showtabline = 2
    end,
  },
}
