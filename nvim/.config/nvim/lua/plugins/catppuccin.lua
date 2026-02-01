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
        neotree = true,
        mason = true,
        telescope = true,
				dap = true,
				cmp = true,
      },
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
