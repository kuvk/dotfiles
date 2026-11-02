local source_labels = {
  lsp = "[LSP]",
  snippets = "[SNIP]",
  path = "[PATH]",
  buffer = "[BUF]",
  cmdline = "[CMD]",
}

return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*",
    build = "make install_jsregexp",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
      require("luasnip").filetype_extend("jinja", { "htmldjango" })
    end,
  },
  {
    "saghen/blink.cmp",
    -- Stable releases, with a prebuilt matcher. Version 2 is still changing.
    version = "1.*",
    dependencies = { "L3MON4D3/LuaSnip" },
    opts = {
      snippets = { preset = "luasnip" },
      keymap = {
        preset = "none",
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      },
      completion = {
        -- Nothing is selected until Tab, so Enter only accepts a chosen item
        list = { selection = { preselect = false, auto_insert = true } },
        menu = {
          scrollbar = false,
          -- Below noice's command window rather than over its bottom edge
          cmdline_position = function()
            local pos = vim.g.ui_cmdline_pos
            if pos then
              return { pos[1], pos[2] }
            end
            return { vim.o.lines - 1, 0 }
          end,
          draw = {
            columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" }, { "source" } },
            components = {
              source = {
                text = function(ctx)
                  return source_labels[ctx.source_id] or ctx.source_id
                end,
                highlight = "BlinkCmpSource",
              },
            },
          },
        },
        documentation = { auto_show = true },
      },
      sources = {
        default = { "lsp", "snippets", "path", "buffer" },
        providers = {
          buffer = { min_keyword_length = 3, score_offset = -10 },
        },
      },
      -- Suggestions for : commands and / searches
      cmdline = {
        keymap = { preset = "cmdline" },
        completion = { menu = { auto_show = true } },
      },
    },
  },
}
