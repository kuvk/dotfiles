return {
  {
    "hrsh7th/cmp-nvim-lsp",
  },
  -- {
  --   "github/copilot.vim",
  --   config = function()
  --     vim.g.copilot_no_tab_map = true
  --     vim.api.nvim_set_keymap(
  --       "i",
  --       "<C-Y>",
  --       'copilot#Accept("<CR>")',
  --       { expr = true, silent = true, noremap = true, replace_keycodes = false }
  --     )
  --   end,
  -- },
  {
    "L3MON4D3/LuaSnip",
    version = "v2.*", -- Replace <CurrentMajor> by the latest released major (first number of latest release)
    -- install jsregexp (optional!).
    build = "make install_jsregexp",
    dependencies = {
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("luasnip").filetype_extend("htmldjango", { "html", "jinja.html" })
      require("luasnip").filetype_extend("html", { "htmldjango", "jinja.html" })
      require("luasnip").filetype_extend("jinja.html", { "htmldjango", "html" })
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    config = function()
      local border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      -- local cmp = require("cmp")
      -- require("luasnip.loaders.from_vscode").lazy_load()
      local luasnip = require("luasnip")
      local cmp = require("cmp")

      cmp.setup({
        snippet = {
          -- REQUIRED - you must specify a snippet engine
          expand = function(args)
            require("luasnip").lsp_expand(args.body) -- For `luasnip` users.
          end,
        },
        window = {
          completion = cmp.config.window.bordered({ border = border, scrollbar = false }),
          documentation = cmp.config.window.bordered({ border = border }),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<CR>"] = cmp.mapping({
            i = function(fallback)
              if cmp.visible() and cmp.get_active_entry() then
                cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
              else
                fallback()
              end
            end,
            s = cmp.mapping.confirm({ select = true }),
            c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
          }),

          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.locally_jumpable(1) then
              luasnip.jump(1)
            else
              fallback()
            end
          end, { "i", "s" }),

          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.locally_jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<C-e>"] = cmp.mapping.abort(),
        }),
        formatting = {
          -- fields = { "kind", "menu", "abbr" },
          format = function(entry, vim_item)
            vim_item.menu = ({
              buffer = "[BUF]",
              nvim_lsp = "[LSP]",
              nvim_lua = "[API]",
              path = "[PATH]",
              luasnip = "[SNIP]",
              npm = "[NPM]",
              neorg = "[NEORG]",
            })[entry.source.name]
            return vim_item
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp", priority = "9" },
          { name = "luasnip", priority = "8" },
        }),
      })
    end,
  },
}
