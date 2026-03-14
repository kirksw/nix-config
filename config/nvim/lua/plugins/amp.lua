return {
  -- {
  --   "sourcegraph/amp.nvim",
  --   branch = "main",
  --   event = "VeryLazy",
  --   opts = { auto_start = true, log_level = "info" },
  -- },
  {
    "folke/sidekick.nvim",
    opts = {
      cli = {
        tools = {
          amp = {
            cmd = { "amp" },
            format = function(text)
              local Text = require("sidekick.text")
              Text.transform(text, function(str)
                return str:find("[^%w/_%.%-]") and ('"' .. str .. '"') or str
              end, "SidekickLocFile")
              local ret = Text.to_string(text)
              -- transform line ranges to a format that amp understands
              ret = ret:gsub("@([^ ]+)%s*:L(%d+):C%d+%-L(%d+):C%d+", "@%1#L%2-%3") -- @file :L5:C20-L6:C8 => @file#L5-6
              ret = ret:gsub("@([^ ]+)%s*:L(%d+):C%d+%-C%d+", "@%1#L%2") -- @file :L5:C9-C29 => @file#L5
              ret = ret:gsub("@([^ ]+)%s*:L(%d+)%-L(%d+)", "@%1#L%2-%3") -- @file :L5-L13 => @file#L5-13
              ret = ret:gsub("@([^ ]+)%s*:L(%d+):C%d+", "@%1#L%2") -- @file :L5:C9 => @file#L5
              ret = ret:gsub("@([^ ]+)%s*:L(%d+)", "@%1#L%2") -- @file :L5 => @file#L5
              return ret
            end,
          },
        },
      },
    },
  },
}
