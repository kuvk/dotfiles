local opt = vim.opt

-- Indentation and Tabs
opt.expandtab = true
opt.autoindent = true
opt.fillchars = { eob = " " }

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
-- Rounded floating windows, LSP hover and signature help included
opt.winborder = "rounded"
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

-- Backspace
opt.backspace = "indent,eol,start"

-- Hide cmdline and strech status line
-- opt.cmdheight = 0
opt.laststatus = 3

opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Add height to cmdline when recording macros
-- vim.cmd([[
--   augroup cmd_macro
--     autocmd!
--     autocmd RecordingEnter * set cmdheight=1
--     autocmd RecordingLeave * set cmdheight=0
--   augroup END
-- ]])
