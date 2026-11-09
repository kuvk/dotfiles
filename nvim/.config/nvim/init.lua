-- Before anything else: true colors, no command line row and no status line (lualine shows
-- it), and the status line in no colors. Otherwise a slow start draws Neovim's default
-- status line, black, before the colorscheme and lualine load.
vim.o.termguicolors = true
vim.o.cmdheight = 0
vim.o.laststatus = 0
vim.api.nvim_set_hl(0, "StatusLine", {})
vim.api.nvim_set_hl(0, "StatusLineNC", {})

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

