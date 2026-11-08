-- Follows the system theme from ~/.local/bin/hyprdori-theme-set.
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
  -- Window borders. The command line, search and the quit confirmation stay in the accent
  -- below, matching lualine's command mode.
  for _, group in ipairs({
    "FloatBorder",
    "LazyGitBorder",
    "WhichKeyBorder",
    "TelescopeBorder",
    "TelescopePromptBorder",
    "TelescopeResultsBorder",
    "TelescopePreviewBorder",
    "BlinkCmpMenuBorder",
    "BlinkCmpDocBorder",
    "BlinkCmpSignatureHelpBorder",
    "NeoTreeFloatBorder",
    "NoicePopupBorder",
    "NoiceSplitBorder",
    "NullLsInfoBorder",
  }) do
    set(0, group, { fg = M.accent2 })
  end
  -- The completion menu without its own background, like the other floating windows
  local menu = vim.api.nvim_get_hl(0, { name = "Pmenu", link = false })
  set(0, "BlinkCmpMenu", { fg = menu.fg })
  set(0, "NoiceConfirmBorder", { fg = p.accent })
  -- Its choices as plain text without a background, the default one (Enter) in the accent
  set(0, "NoiceFormatConfirm", { fg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg })
  set(0, "NoiceFormatConfirmDefault", { fg = p.accent })
  -- Lines between splits (shapes in options.lua fillchars), in the file tree's background
  local tree = vim.api.nvim_get_hl(0, { name = "NeoTreeNormal", link = false }).bg
  local divider = tree and string.format("#%06x", tree) or p.dark_bg
  set(0, "WinSeparator", { fg = divider })
  set(0, "NeoTreeWinSeparator", { fg = divider })
  -- Trouble in the editor's background, like a file; its cursor line is CursorLine
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
  set(0, "TroubleNormal", { bg = normal })
  set(0, "TroubleNormalNC", { bg = normal })
  -- Indent guides: the current block's in accent2, the rest as the colorscheme draws them
  set(0, "IblScope", { fg = M.accent2 })
  -- Keywords in comments (treesitter's comment parser), as bold text without a background:
  -- TODO WIP accent; NOTE INFO XXX accent2; WARNING HACK FIX accent3; FIXME BUG ERROR red
  set(0, "@comment.todo", { fg = p.accent, bold = true })
  set(0, "@comment.note", { fg = M.accent2, bold = true })
  set(0, "@comment.warning", { fg = M.accent3, bold = true })
  set(0, "@comment.error", { fg = p.red, bold = true })
  -- Command and search windows (noice.lua)
  -- Command line and search popups: borders green like lualine's command mode, which both
  -- are; the icon in accent, the typed text in accent2
  for _, group in ipairs({ "Border", "BorderSearch", "Title", "TitleSearch" }) do
    set(0, "NoiceCmdlinePopup" .. group, { fg = p.green })
  end
  for _, group in ipairs({ "NoiceCmdlineIcon", "NoiceCmdlineIconSearch" }) do
    set(0, group, { fg = p.accent })
  end
  local popup = vim.api.nvim_get_hl(0, { name = "NoiceCmdlinePopup", link = false })
  set(0, "NoiceCmdlinePopup", { fg = M.accent2, bg = popup.bg })
  -- Folders in accent, like yazi, eza and ls: neo-tree, the completion menu's folder kind and
  -- everything that uses Directory (file pickers, :e completion, netrw)
  for _, group in ipairs({ "Directory", "NeoTreeDirectoryIcon", "NeoTreeDirectoryName", "BlinkCmpKindFolder", "CmpItemKindFolder" }) do
    set(0, group, { fg = p.accent })
  end
  set(0, "NeoTreeRootName", { fg = p.accent, bold = true })
  -- Files without an icon of their own in text, as in yazi and eza
  set(0, "NeoTreeFileIcon", { fg = p.fg })
  -- One cursor line everywhere: the editor, neo-tree, and yazi's hover highlight (hyprdori-theme-set)
  if M.cursorline then
    local line = vim.api.nvim_get_hl(0, { name = "CursorLine", link = false })
    line.bg = M.cursorline
    set(0, "CursorLine", line)
    set(0, "NeoTreeCursorLine", { bg = M.cursorline })
  end
  -- Links like yazi's: icon and name in accent3, the target accent (red when broken)
  set(0, "NeoTreeLinkIcon", { fg = M.accent3 })
  set(0, "NeoTreeLinkName", { fg = M.accent3, bold = true })
  set(0, "NeoTreeSymbolicLinkTarget", { fg = p.accent })
  set(0, "NeoTreeBrokenLinkTarget", { fg = p.red })
  -- The "File Explorer" label above neo-tree (bufferline's offset), in accent on the status line
  local status = vim.api.nvim_get_hl(0, { name = "StatusLine", link = false })
  set(0, "NeoTreeExplorerLabel", { fg = p.accent, bg = status.bg, bold = true })
  -- Dashboard: the NEOVIM lettering in accent, the logo in accent2, buttons in accent3
  -- with their keys in accent
  set(0, "AlphaHeader", { fg = p.accent })
  set(0, "AlphaButtons", { fg = M.accent3 })
  set(0, "AlphaShortcut", { fg = p.accent })
  set(0, "AlphaFooter", { fg = M.accent2 })
  -- Diagnostic text at the end of a line, with no background
  for _, level in ipairs({ "Error", "Warn", "Info", "Hint" }) do
    local group = "DiagnosticVirtualText" .. level
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    hl.bg = nil
    set(0, group, hl)
  end
end

-- icons.toml's files and extensions on top of nvim-web-devicons' own (folders and links are
-- neo-tree's, see plugins/neo-tree.lua)
local function apply_devicons()
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok or not M.icons then
    return
  end
  local overrides = {}
  for _, kind in ipairs({ "files", "exts" }) do
    for name, icon in pairs(M.icons[kind] or {}) do
      overrides[name] = { icon = icon[1], color = icon[2], name = "Hyprdori" .. name:gsub("%W", "_") }
    end
  end
  if next(overrides) then
    devicons.set_icon(overrides)
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
  M.accent2 = theme.accent2 or M.palette.blue
  M.accent3 = theme.accent3 or M.palette.orange
  M.cursorline = theme.cursorline
  M.icons = theme.icons or { dirs = {}, files = {}, exts = {} }
  apply_devicons()
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

-- Window corners: square in Work-Game or with the corner radius at 0, rounded otherwise.
-- Most windows follow vim.o.winborder; the rest are updated here. The command line,
-- search and confirm windows (noice) and the completion menu (blink.cmp) keep their
-- corners until Neovim restarts.
function M.border()
  return M.square() and "single" or "rounded"
end

function M.apply_shape()
  local border = M.border()
  vim.o.winborder = border
  vim.g.lazygit_floating_window_border_chars = border == "single"
      and { "┌", "─", "┐", "│", "┘", "─", "└", "│" }
    or { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
  -- theme-set rewrites LazyGit's config with the new corners right after; an open one rereads it
  vim.defer_fn(refresh_lazygit, 500)
  local ok, lazy_config = pcall(require, "lazy.core.config")
  if ok then
    lazy_config.options.ui.border = border
  end
  if package.loaded["telescope.config"] then
    require("telescope.config").values.borderchars = border == "single"
        and { "─", "│", "─", "│", "┌", "┐", "┘", "└" }
      or { "─", "│", "─", "│", "╭", "╮", "╯", "╰" }
  end
  local which_key = package.loaded["which-key.config"] and require("which-key.config").options
  if which_key then
    which_key.win.border = border
  end
  local views = package.loaded["noice.config"] and require("noice.config").options.views
  if views then
    for _, view in ipairs({ "cmdline_popup", "confirm" }) do
      views[view] = vim.tbl_deep_extend("force", views[view] or {}, { border = { style = border } })
    end
  end
end

function M.setup()
  if M.started then
    return
  end
  M.started = true
  vim.api.nvim_create_autocmd("ColorScheme", { callback = custom_highlights })
  vim.api.nvim_create_autocmd("User", { pattern = { "ThemeShape", "VeryLazy" }, callback = M.apply_shape })
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
