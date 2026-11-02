-- Only for searching TODOs (<leader>ft). Treesitter already colors them (theme.lua).
return {
  "folke/todo-comments.nvim",
  cmd = { "TodoTelescope", "TodoTrouble", "TodoQuickFix" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    signs = false,
    highlight = { keyword = "", before = "", after = "" },
  },
}
