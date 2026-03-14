return {
  {
    -- piggyback on lspconfig entry to add detection in init
    "neovim/nvim-lspconfig",
    optional = true,
    init = function()
      -- 1) Path-based detection for typical Helm layouts
      vim.filetype.add({
        pattern = {
          [".*/templates/.*%.ya?ml"] = "helm",
          [".*/templates/.*%.tpl"] = "helm",
          [".*/manifests/.*%.ya?ml"] = "helm",
          [".*/manifests/.*%.tpl"] = "helm",
        },
        extension = {
          -- Treat foo.yaml.tmpl and foo.yml.tmpl as helm
          tmpl = function(path, _)
            if path:match("%.ya?ml%.tmpl$") then
              return "helm"
            end
          end,
        },
      })

      -- 2) Content heuristic for YAML files outside standard paths
      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        group = vim.api.nvim_create_augroup("helm_yaml_detect_overlay", { clear = true }),
        pattern = { "*.yaml", "*.yml" },
        callback = function(args)
          local bufnr = args.buf

          -- Don’t override if already detected
          if vim.bo[bufnr].filetype == "helm" then
            return
          end

          -- Fast scan: first 200 lines for Go template delimiters (including trim {{- -}})
          local max_lines = math.min(200, vim.api.nvim_buf_line_count(bufnr))
          local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
          local text = table.concat(lines, "\n")

          -- Detect any {{ ... }} with optional trim markers
          -- Two lightweight patterns to avoid catastrophic backtracking
          if text:find("{{%-?[^}]-%-?}}") or text:find("{{[^}]-}}") then
            vim.bo[bufnr].filetype = "helm"
          end
        end,
      })
    end,
  },
  {
    "allaman/kustomize.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      -- (optional for better directory handling in "List resources")
      "nvim-neo-tree/neo-tree.nvim",
    },
    ft = "yaml",
    opts = {},
  },
}
