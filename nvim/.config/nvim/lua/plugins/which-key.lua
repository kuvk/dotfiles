-- Press <leader> and wait: lists the next keys, with their descriptions from
-- config/keymaps.lua. Groups are named here.
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    delay = 500, -- ms before the popup opens
    win = { border = "rounded" },
    spec = {
      { "<leader>D", group = "Debug" },
      { "<leader>S", group = "Sessions" },
      { "<leader>c", group = "Code and buffers" },
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Code and git" },
      { "<leader>l", group = "Lazy and LazyGit" },
      { "<leader>m", group = "Markdown and Mason" },
      { "<leader>n", group = "Search" },
      { "<leader>s", group = "Splits" },
      { "<leader>t", group = "Tabs and guides" },
      { "<leader>x", group = "Diagnostics" },
    },
  },
}
