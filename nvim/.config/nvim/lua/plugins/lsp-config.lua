return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
        },
      })
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- stylua only formats, through none-ls with its indent settings
        automatic_enable = { exclude = { "stylua" } },
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
          -- Types and navigation here; style, imports and undefined names from Ruff
          pyright = { autoImportCompletion = true, disableOrganizeImports = true },
          python = {
            analysis = {
              autoImportCompletion = true,
              autoSearchPaths = true,
              diagnosticMode = "openFilesOnly",
              useLibraryCodeForTypes = true,
              typeCheckingMode = "basic",
              diagnosticSeverityOverrides = {
                reportUndefinedVariable = "none",
              },
            },
          },
        },
      })
      vim.lsp.config("ruff", {
        capabilities = capabilities,
        init_options = {
          settings = {
            lint = {
              -- Star imports and imports not at the top
              ignore = { "F403", "F405", "E402" },
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

    end,
  },
}
