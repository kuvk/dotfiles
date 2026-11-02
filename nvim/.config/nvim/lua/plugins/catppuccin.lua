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
    })
    -- Apply the system theme here, before other plugins (bufferline, lualine)
    -- set up their highlights. See lua/theme.lua.
    require("theme").setup()
  end,
}
