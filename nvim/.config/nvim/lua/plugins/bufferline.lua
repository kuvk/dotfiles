-- Highlights that differ from bufferline's defaults, from the current theme
-- (they used to be hardcoded Mocha values)
local function custom_highlights()
  local p = require("theme").palette
  local fill = p.dark_bg
  if fill then
    vim.api.nvim_set_hl(0, "BufferLineFill", { bg = fill })
    vim.api.nvim_set_hl(0, "BufferLineSeparator", { fg = fill })
    vim.api.nvim_set_hl(0, "BufferLineSeparatorSelected", { fg = fill })
  end
  if p.blue then
    vim.api.nvim_set_hl(0, "StatusLine", { fg = p.blue })
  end
end

local options = {
  -- mode = "tabs",
  always_show_bufferline = false,
  themable = true,
  color_icons = true,
  indicator = {
    icon = "", -- "▎" this should be omitted if indicator style is not 'icon'
    style = "none", -- "icon" | "underline" | "none",
  },
  -- style_preset = require("bufferline").style_preset.minimal,
  tab_size = 20,
  -- separator_style = "slant",
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
      text = "File Explorer",
      highlight = "StatusLine",
      text_align = "left",
    },
  },
}

local function setup()
  -- Re-running setup rebuilds bufferline's highlights, file icon backgrounds
  -- included, from the colorscheme now in use
  require("bufferline").setup({ options = options })
  custom_highlights()
end

return {
  "akinsho/bufferline.nvim",
  -- version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    setup()
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        vim.schedule(setup)
      end,
    })
    vim.keymap.set("n", "<leader>co", ":BufferLineCloseOthers<CR>", {})
    vim.keymap.set("n", "<leader>,", ":BufferLineCyclePrev<CR>", {})
    vim.keymap.set("n", "<leader>.", ":BufferLineCycleNext<CR>", {})
  end,
}
