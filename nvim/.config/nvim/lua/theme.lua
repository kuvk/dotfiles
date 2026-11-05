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
end

function M.setup()
  if M.started then
    return
  end
  M.started = true
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
    end
  end))
end

return M
