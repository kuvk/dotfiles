-- Follows the system theme from ~/.config/scripts/theme-set.py.
-- theme-set writes ~/.config/theme/current/nvim.lua; running instances
-- pick up the change through a file watcher.
local M = {}

local dir = vim.fn.expand("~/.config/theme/current")
local file = dir .. "/nvim.lua"
local fallback = { name = "fallback", colorscheme = "catppuccin-mocha", background = "dark" }

local function read()
  local ok, theme = pcall(dofile, file)
  if ok and type(theme) == "table" and theme.colorscheme then
    return theme
  end
  return fallback
end

-- Palette of the current theme (aether keys: bg, dark_bg, fg, blue, ...)
M.palette = {}

-- Highlights the config sets itself, in the current theme's colors. Change them here.
local function custom_highlights()
  local p = M.palette
  local set = vim.api.nvim_set_hl
  set(0, "LazyGitBorder", { fg = p.accent })
  set(0, "AlphaHeader", { fg = p.blue })
  set(0, "AlphaButtons", { fg = p.accent })
  set(0, "AlphaShortcut", { fg = p.blue })
  set(0, "AlphaFooter", { fg = p.magenta, italic = true })
  -- Diagnostic text at the end of a line, with no background
  for _, level in ipairs({ "Error", "Warn", "Info", "Hint" }) do
    local group = "DiagnosticVirtualText" .. level
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg = nil
    set(0, group, hl)
  end
end

-- An open LazyGit rereads its config when it regains focus, which brings its new colors
local function refresh_lazygit()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" and vim.api.nvim_buf_get_name(buf):find("lazygit", 1, true) then
      vim.fn.chansend(vim.b[buf].terminal_job_id, "\27[O\27[I")
    end
  end
end

function M.apply()
  local theme = read()
  if M.current == theme.name and vim.g.colors_name == theme.colorscheme then
    return
  end
  M.current = theme.name
  M.palette = theme.aether or {}
  vim.o.background = theme.background or "dark"

  -- aether builds its colors from the palette, so it needs setup per theme
  if theme.colorscheme == "aether" and theme.aether then
    pcall(function()
      require("lazy").load({ plugins = { "aether" } })
      require("aether").setup({ colors = theme.aether })
    end)
  end

  if not pcall(vim.cmd.colorscheme, theme.colorscheme) then
    vim.notify("theme: colorscheme '" .. theme.colorscheme .. "' not available", vim.log.levels.WARN)
    vim.cmd.colorscheme(fallback.colorscheme)
  end
  -- selected text looks the same as in the terminal and everywhere else
  if theme.selection then
    vim.api.nvim_set_hl(0, "Visual", theme.selection)
  end
  vim.api.nvim_set_hl(0, "YankHighlight", theme.yank or { link = "IncSearch" })
  refresh_lazygit()
end

-- Square corners in Work-Game or with the corner radius at 0 (theme-set --shape)
function M.square()
  local file = io.open(dir .. "/shape")
  if not file then
    return false
  end
  local shape = file:read("*l")
  file:close()
  return shape == "square"
end

function M.setup()
  if M.started then
    return
  end
  M.started = true
  vim.api.nvim_create_autocmd("ColorScheme", { callback = custom_highlights })
  M.apply()

  if vim.fn.isdirectory(dir) == 0 then
    return
  end
  local uv = vim.uv or vim.loop
  local watcher = uv.new_fs_event()
  -- theme-set replaces the file atomically, so watch the directory
  watcher:start(dir, {}, vim.schedule_wrap(function(err, name)
    if not err and name == "nvim.lua" then
      M.apply()
    elseif not err and name == "shape" then
      vim.api.nvim_exec_autocmds("User", { pattern = "ThemeShape" })
    end
  end))
end

return M
