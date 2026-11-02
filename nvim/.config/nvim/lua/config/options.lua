local opt = vim.opt

-- Indentation and Tabs
opt.expandtab = true
opt.autoindent = true

opt.number = true
opt.relativenumber = true
opt.wrap = false
opt.showmode = false

-- Cursor blink
opt.guicursor:append("n-v-c-i:blinkon500-blinkoff500")

-- Search
opt.ignorecase = true
opt.smartcase = true

opt.termguicolors = true
opt.background = "dark"
opt.signcolumn = "yes"
-- Rounded floating windows, square in Work-Game (theme.lua), hover and signature help included
opt.winborder = require("theme").border()
-- Split dividers: the vertical ones fill their column and the horizontal ones half a
-- row, in the file tree's background (theme.lua), so they look about equally thick
opt.fillchars = {
  eob = " ",
  vert = "█",
  vertleft = "█",
  vertright = "█",
  verthoriz = "█",
  horiz = "▀",
  horizup = "▀",
  horizdown = "▀",
}
opt.cursorline = true

-- Turn off swap and enable mouse
opt.swapfile = false
opt.mousemoveevent = true

-- Split to right and bottom
opt.splitright = true
opt.splitbelow = true

-- System clipboard for y, d and p. Set after startup, since finding the provider
-- takes a moment. Over SSH, through the terminal (OSC 52) instead.
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end
vim.schedule(function()
  opt.clipboard:append("unnamedplus")
end)

-- Keep lines in view around the cursor, preview :s as you type, respond faster
-- (diagnostics, git signs), and ask to save instead of refusing to quit
opt.scrolloff = 8
opt.inccommand = "split"
opt.updatetime = 250
opt.confirm = true

-- Undo survives closing a file (autocmds.lua leaves out private files)
opt.undofile = true

-- No plugins here use these language hosts
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0

-- Backspace
opt.backspace = "indent,eol,start"

-- No command line row, noice.lua draws it. One status line across splits.
opt.cmdheight = 0
opt.laststatus = 3

opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
