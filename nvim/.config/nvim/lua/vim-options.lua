local opt = vim.opt

-- Indentation and Tabs
-- opt.tabstop = 4
-- opt.shiftwidth = 4
opt.expandtab = false
opt.autoindent = true

-- Set tab width for specific filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "lua",
    "html",
    "jinja.html",
    "javascript",
    "jquery",
    "json",
    "jsonc",
    "xml",
    "scss",
    "django",
    "css",
  },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.shiftwidth = 2
    vim.opt_local.softtabstop = 2
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "*" },
  callback = function()
    local two_space_ft = {
      lua = true,
      html = true,
      ["jinja.html"] = true,
      javascript = true,
      jquery = true,
      json = true,
      jsonc = true,
      xml = true,
      scss = true,
      css = true,
      django = true,
    }
    local ft = vim.bo.filetype
    if not two_space_ft[ft] then
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
      vim.opt_local.softtabstop = 4
    end
  end,
})

opt.number = true
opt.relativenumber = true
opt.wrap = false
opt.showmode = false

-- Cursor blink
opt.guicursor:append("n-v-c-i:blinkon500-blinkoff500")

-- Searc
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

opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Add height to cmdline when recording macros
-- vim.cmd([[
--   augroup cmd_macro
--     autocmd!
--     autocmd RecordingEnter * set cmdheight=1
--     autocmd RecordingLeave * set cmdheight=0
--   augroup END
-- ]])

-- colorcolumn
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufRead", "BufNewFile" }, {
  callback = function()
    local ft = vim.bo.filetype
    local with_col80 = {
      python = true,
      c = true,
      cpp = true,
      sh = true,
    }

    if with_col80[ft] then
      vim.cmd("set colorcolumn=80")
    else
      vim.cmd("set colorcolumn=0")
    end
  end,
})
