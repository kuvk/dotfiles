local opt = vim.opt

-- Indentation and Tabs
-- opt.tabstop = 4
-- opt.shiftwidth = 4
opt.expandtab = false
opt.autoindent = true
opt.fillchars = { eob = " " }

-- Tab width by filetype: 2 for these, 4 for the rest
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
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    local width = two_space_ft[ev.match] and 2 or 4
    vim.opt_local.tabstop = width
    vim.opt_local.shiftwidth = width
    vim.opt_local.softtabstop = width
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

-- System clipboard for y, d and p. Set after startup, since finding the provider
-- takes a moment. Over SSH, through the terminal (OSC 52) instead.
if vim.env.SSH_TTY then
  vim.g.clipboard = "osc52"
end
vim.schedule(function()
  opt.clipboard:append("unnamedplus")
end)

-- Flash what was just copied
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

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
      lua = true,
    }

    if with_col80[ft] then
      vim.cmd("set colorcolumn=80")
    else
      vim.cmd("set colorcolumn=0")
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "conf" },
  callback = function(ev)
    vim.bo[ev.buf].commentstring = "# %s"
  end,
})
