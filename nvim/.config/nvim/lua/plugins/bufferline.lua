return {
  "akinsho/bufferline.nvim",
  -- version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    require("bufferline").setup({
      options = {
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
          local icon = level:match("error") and " " or " "
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
      },
    })
    vim.cmd("highlight BufferLineFill guibg=#181826")
    vim.cmd("highlight BufferLineSeparator guifg=#181826")
    vim.cmd("highlight BufferLineSeparatorSelected guifg=#181826")
    vim.cmd("highlight StatusLine guifg=#89b4fb")
    vim.keymap.set("n", "<leader>co", ":BufferLineCloseOthers<CR>", {})
    vim.keymap.set("n", "<leader>,", ":BufferLineCyclePrev<CR>", {})
    vim.keymap.set("n", "<leader>.", ":BufferLineCycleNext<CR>", {})
  end,
}
