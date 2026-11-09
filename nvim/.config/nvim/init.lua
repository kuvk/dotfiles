-- While starting: true colors, no status line until lualine shows it, and a command line row.
-- Without that row a message while plugins load (cmdheight 0) takes over the bottom rows,
-- black, before the colorscheme draws them; noice draws the command line once Neovim has
-- started, and the row goes (options.lua).
vim.o.termguicolors = true
vim.o.laststatus = 0

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("config.options")
require("config.keymaps")
require("config.autocmds")

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  ui = {
    border = require("theme").border(),
  },
  install = { colorscheme = { "catppuccin" } },
  rocks = { enabled = false },
})

