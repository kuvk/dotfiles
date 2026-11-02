return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
        },
      })
      vim.keymap.set("n", "<leader>mm", "<cmd>Mason<CR>")
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "lua_ls",
          "ts_ls",
          "pyright",
          "jinja_lsp",
          "bashls",
          "clangd",
          "qmlls",
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      require("lspconfig.ui.windows").default_options = {
        border = "rounded",
      }

      vim.diagnostic.config({
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.INFO] = "󰋼 ",
            [vim.diagnostic.severity.HINT] = "󰌵 ",
          },
          numhl = {
            [vim.diagnostic.severity.ERROR] = "",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.HINT] = "",
            [vim.diagnostic.severity.INFO] = "",
          },
        },
      })

      vim.lsp.config("lua_ls", {
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim", "hl", "catppuccin" },
            },
          },
        },
      })
      vim.lsp.config("jinja_lsp", {
        capabilities = capabilities,
      })
      vim.lsp.config("pyright", {
        capabilities = capabilities,
        settings = {
          pyright = { autoImportCompletion = true },
          python = {
            analysis = {
              autoImportCompletion = true,
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              useLibraryCodeForTypes = true,
              typeCheckingMode = "off",
            },
          },
        },
      })
      vim.lsp.config("ts_ls", {
        capabilities = capabilities,
      })
      vim.lsp.config("bashls", {
        capabilities = capabilities,
        filetypes = { "sh", "zsh", "bash" },
      })
      vim.lsp.config("clangd", {
        capabilities = capabilities,
      })
      vim.lsp.config("qmlls", {
        capabilities = capabilities,
        cmd = { "qmlls6" },
        filetypes = { "qml", "qmljs" },
        offset_encoding = "utf-8", -- sometimes helps with token position bugs
        on_attach = function(client, _)
          client.server_capabilities.semanticTokensProvider = nil
        end,
      })

      -- Only in buffers with a language server
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
          vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts)
        end,
      })
      vim.cmd([[highlight DiagnosticVirtualTextError guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextWarn guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextInfo guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextHint guibg=none]])
    end,
  },
}
