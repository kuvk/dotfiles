return {
  "catppuccin/nvim",
  lazy = false,
  name = "catppuccin",
  priority = 1000,
  config = function()
    require("catppuccin").setup({
      -- transparent_background = true,
      float = {
        transparent = true,
      },
      integrations = {
        alpha = true,
        neotree = true,
        mason = true,
        telescope = true,
        dap = true,
        cmp = true,
      },
      custom_highlights = function(colors)
        return {
          AlphaHeader = { fg = colors.blue },
          AlphaButtons = { fg = colors.peach },
          AlphaShortcut = { fg = colors.blue },
          AlphaFooter = { fg = colors.mauve, style = { "italic" } },
        }
      end,
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
