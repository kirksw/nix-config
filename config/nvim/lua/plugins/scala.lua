return {
  recommended = function()
    return LazyVim.extras.wants({
      ft = "scala",
      root = { "build.sbt", "build.sc", "build.gradle", "pom.xml", "build.mill" },
    })
  end,
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "scala" } },
  },
  {
    "scalameta/nvim-metals",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      {
        "<leader>me",
        function()
          require("telescope").extensions.metals.commands()
        end,
        desc = "Metals commands",
      },
      {
        "<leader>mc",
        function()
          require("metals").compile_cascade()
        end,
        desc = "Metals compile cascade",
      },
      {
        "<leader>mh",
        function()
          require("metals").hover_worksheet()
        end,
        desc = "Metals hover worksheet",
      },
    },
    ft = { "scala", "sbt", "java", "mill" },
    opts = function()
      local metals_config = require("metals").bare_config()

      metals_config.init_options.statusBarProvider = "off"

      metals_config.settings = {
        verboseCompilation = true,
        showImplicitArguments = true,
        showImplicitConversionsAndClasses = true,
        showInferredType = true,
        superMethodLensesEnabled = true,
        excludedPackages = {
          "akka.actor.typed.javadsl",
          "org.apache.pekko.actor.typed.javadsl",
          "com.github.swagger.akka.javadsl",
        },
        testUserInterface = "Test Explorer",
      }

      metals_config.on_attach = function(client, bufnr)
        require("metals").setup_dap()

        -- Override the default nvim-metals BufEnter autocmd that broadcasts
        -- metals/didFocusTextDocument to ALL LSP clients on the buffer.
        -- Scope the notification to only the Metals client so other servers
        -- (e.g. nil_ls for Nix files) don't receive it and crash.
        local group = vim.api.nvim_create_augroup("nvim-metals-focus", { clear = true })
        vim.api.nvim_create_autocmd("BufEnter", {
          pattern = { "*" },
          callback = function()
            local metals = vim.lsp.get_clients({ bufnr = 0, name = "metals" })[1]
            if metals then
              metals.notify("metals/didFocusTextDocument", vim.uri_from_bufnr(0))
            end
          end,
          group = group,
        })
      end

      return metals_config
    end,
    config = function(self, metals_config)
      local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = self.ft,
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = nvim_metals_group,
      })
    end,
  },
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      -- Debug settings
      local dap = require("dap")
      dap.configurations.scala = {
        {
          type = "scala",
          request = "launch",
          name = "RunOrTest",
          metals = {
            runType = "runOrTestFile",
            --args = { "firstArg", "secondArg", "thirdArg" }, -- here just as an example
          },
        },
        {
          type = "scala",
          request = "launch",
          name = "Test Target",
          metals = {
            runType = "testTarget",
          },
        },
      }
    end,
  },
}
