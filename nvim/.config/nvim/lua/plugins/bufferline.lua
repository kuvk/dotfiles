-- Backgrounds for every part of the bar, given to bufferline itself so the file icon groups it
-- makes later get them too: only the selected buffer has one, everything else (other buffers,
-- the Neo Tree title, the arrows when buffers don't fit) sits on the editor's
local function bar_highlights()
  local p = require("theme").palette
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
  if not p.muted or not normal then
    return {}
  end
  normal = string.format("#%06x", normal)
  local defaults = require("bufferline.config").get().highlights or {}
  local result = {}
  for name in pairs(defaults) do
    result[name] = { bg = name:find("selected") and p.lighter_bg or normal}
    if name:find("separator") then
      result[name].fg = normal
    end
  end
  return result
end

local function custom_highlights()
  local p = require("theme").palette
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
  vim.api.nvim_set_hl(0, "NeoTreeExplorerLabel", { fg = p.accent, bg = normal, bold = true })
  if p.blue then
    vim.api.nvim_set_hl(0, "StatusLine", { fg = p.blue })
  end
end

local options = {
  always_show_bufferline = false,
  themable = true,
  color_icons = true,
  indicator = {
    icon = "", -- "▎" this should be omitted if indicator style is not 'icon'
    style = "none", -- "icon" | "underline" | "none",
  },
  tab_size = 20,
  enforce_regular_tabs = true,
  hover = {
    enabled = true,
    delay = 200,
    reveal = { "close" },
  },
  diagnostics = "nvim_lsp",
  diagnostics_indicator = function(count, level)
    local icon = level:match("error") and "\u{f057} " or "\u{f071} "
    return " " .. icon .. count
  end,
  offsets = {
    {
      filetype = "neo-tree",
      text = "Neo Tree",
      highlight = "NeoTreeExplorerLabel", -- accent (lua/theme.lua)
      text_align = "left",
      -- covers the divider's column too, so the line beside the tree reaches the top
      padding = 1,
    },
  },
}

-- The tab line, and its "File Explorer" title, shows with one buffer only while Neo-tree is open
local function update_tabline()
  local tree_open = false
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then
      tree_open = true
    end
  end
  options.always_show_bufferline = tree_open
  require("bufferline.config").get().options.always_show_bufferline = tree_open
  local several = #vim.fn.getbufinfo({ buflisted = 1 }) > 1
  local shown = tree_open or several
  vim.o.showtabline = shown and 2 or 0
end

local function setup()
  -- Re-running setup rebuilds bufferline's highlights, file icon backgrounds
  -- included, from the colorscheme now in use
  require("bufferline").setup({ options = options })
  -- again with the backgrounds, now that bufferline's own highlight names are known; its
  -- groups are set as defaults, which leave defined ones alone, so they're cleared first
  local highlights = bar_highlights()
  for _, group in ipairs(vim.fn.getcompletion("BufferLine", "highlight")) do
    vim.api.nvim_set_hl(0, group, {})
  end
  require("bufferline").setup({ options = options, highlights = highlights })
  custom_highlights()
end

return {
  "akinsho/bufferline.nvim",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    setup()
    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinClosed", "BufAdd", "BufDelete", "TabEnter" }, {
      callback = function()
        vim.schedule(update_tabline)
      end,
    })
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.schedule(setup)
      end,
    })
  end,
}
