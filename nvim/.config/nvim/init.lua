-- Lazy package manager
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


require("vim-options")
require("vim-keymaps")

-- Setup lazy.nvim
require("lazy").setup("plugins")

-- vim.cmd("hi jinjaVarBlock guifg=#cdd6f4")
-- vim.cmd("hi jinjaTagBlock guifg=#cdd6f4")
-- vim.cmd("hi jinjaArgument guifg=#94e2d5")
-- vim.cmd("hi jinjaStatement guifg=#cba6f7")
-- vim.cmd("hi htmlTagName guifg=#89b4fa")
-- vim.cmd("hi htmlTag guifg=#94e2d5")
-- vim.cmd("hi htmlEndTag guifg=#94e2d5")
