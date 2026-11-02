-- Command line in a floating window, and messages as small floating text
-- (options.lua removes the bottom row). :Noice lists past messages.
return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    cmdline = { view = "cmdline_popup" },
    messages = {
      view = "mini",
      view_error = "mini",
      view_warn = "mini",
    },
    presets = { long_message_to_split = true },
    -- blink.cmp draws the suggestions; the language server keeps its usual windows
    popupmenu = { enabled = false },
    notify = { enabled = false },
    lsp = {
      progress = { enabled = false },
      hover = { enabled = false },
      signature = { enabled = false },
      message = { enabled = false },
    },
  },
}
