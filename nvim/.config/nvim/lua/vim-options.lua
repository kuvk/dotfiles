local opt = vim.opt

-- Indentation and Tabs
opt.tabstop = 4
opt.shiftwidth = 4
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
opt.cursorline = true

-- Turn off swap and enable mouse
opt.swapfile = false
opt.mousemoveevent = true

-- Split to right and bottom
opt.splitright = true
opt.splitbelow = true

-- Yank to clipboard
opt.clipboard:append("unnamedplus")

-- Backspace
opt.backspace = "indent,eol,start"

-- Hide cmdline and strech status line
-- opt.cmdheight = 0
opt.laststatus = 3

opt.sessionoptions="blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Add height to cmdline when recording macros
-- vim.cmd([[
--   augroup cmd_macro
--     autocmd!
--     autocmd RecordingEnter * set cmdheight=1
--     autocmd RecordingLeave * set cmdheight=0
--   augroup END
-- ]])

-- colocolumn for python
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufRead", "BufNewFile" }, {
  callback = function()
    if vim.bo.filetype == "python" then
      vim.cmd("set colorcolumn=80")
    else
      vim.cmd("set colorcolumn=0")
    end
  end,
})
