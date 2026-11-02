-- Tab width by filetype: 2 for these, 4 for the rest. Spaces, except where a
-- language needs tabs (its own filetype settings turn expandtab off)
local two_space_ft = {
  lua = true,
  html = true,
  javascript = true,
  jquery = true,
  json = true,
  jsonc = true,
  xml = true,
  scss = true,
  css = true,
  django = true,
  htmldjango = true,
  qml = true,
  jinja = true,
  yaml = true,
  markdown = true,
  typescript = true,
  typescriptreact = true,
  javascriptreact = true,
}
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    local width = two_space_ft[ev.match] and 2 or 4
    vim.opt_local.tabstop = width
    vim.opt_local.shiftwidth = width
    vim.opt_local.softtabstop = width
  end,
})

-- Undo history is stored as plain text, so not for these
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  pattern = { "/tmp/*", "/dev/shm/*", "/run/user/*", "*/.ssh/*", "*/.gnupg/*", "*/.password-store/*", "*.env", ".env*" },
  callback = function(ev)
    vim.bo[ev.buf].undofile = false
  end,
})

-- Flash what was just copied
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ higroup = "YankHighlight", timeout = 150 })
  end,
})

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

-- Comments use Neovim's built-in gc. Filetypes it has no format for:
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "conf" },
  callback = function(ev)
    vim.bo[ev.buf].commentstring = "# %s"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "jinja" },
  callback = function(ev)
    vim.bo[ev.buf].commentstring = "{# %s #}"
  end,
})

-- Jinja templates: .j2, .jinja and .jinja2 files, and HTML with template tags in
-- its first 50 lines. Highlighted by treesitter (after/queries/jinja/injections.scm).
vim.filetype.add({
  extension = {
    j2 = "jinja",
    jinja = "jinja",
    jinja2 = "jinja",
    html = function(_, bufnr)
      for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)) do
        if line:find("{{.*}}") or line:find("{%%%-?%s*%a") or line:find("{#") then
          return "jinja"
        end
      end
      return "html"
    end,
  },
  pattern = {
    [".*%.jinja%.html"] = "jinja",
    [".*%.html%.j2"] = "jinja",
  },
})
