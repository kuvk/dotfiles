return {
  "nvim-telescope/telescope.nvim",
  version = "*",
  -- Loaded on first use (its keys run :Telescope), not at startup
  cmd = "Telescope",
  -- Selection menus (code actions, ...) are Telescope's ui-select ones: the first one loads it
  init = function()
    local builtin = vim.ui.select
    vim.ui.select = function(...)
      vim.ui.select = builtin
      require("lazy").load({ plugins = { "telescope.nvim" } })
      return vim.ui.select(...)
    end
  end,
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    "nvim-telescope/telescope-ui-select.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local telescope = require("telescope")
    telescope.setup({
      defaults = {
        -- q closes in normal mode (jk or Esc from the prompt) and types a q in insert mode
        mappings = { n = { q = "close" } },
        -- the current shape's corners (lua/theme.lua), also when it loads after a change
        borderchars = require("theme").telescope_borders(),
      },
      extensions = {
        ["ui-select"] = {
          require("telescope.themes").get_dropdown({}),
        },
      },
    })
    telescope.load_extension("fzf")
    telescope.load_extension("ui-select")
  end,
}
