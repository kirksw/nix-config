return {
  -- Enable wrap for markdown
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown", "md" },
        callback = function()
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.spell = true
        end,
      })
    end,
  },

  -- Disable line length in markdownlint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        markdownlint = {
          args = {
            "--disable",
            "MD013", -- Line length rule
            "--",
          },
        },
      },
    },
  },
}
