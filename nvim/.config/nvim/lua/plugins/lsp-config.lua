return {
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
    end,
    vim.keymap.set("n", "<leader>mm", ":Mason<CR>", {}),
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
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local lspconfig = require("lspconfig")
      require("lspconfig.ui.windows").default_options = {
        border = "rounded",
      }

      local signs = { Error = " ", Warn = " ", Hint = "󰌵 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
      end

      lspconfig.lua_ls.setup({ capabilities = capabilities })
      lspconfig.jinja_lsp.setup({ capabilities = capabilities })
      lspconfig.pyright.setup({
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
      lspconfig.ts_ls.setup({ capabilities = capabilities })
      lspconfig.bashls.setup({
        capabilities = capabilities,
        settings = {
          filetypes = { "sh", "zsh", "bash" },
          bashIde = {
            shellcheckPath = "",
          },
        },
      })
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      vim.keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, {})
      vim.cmd([[highlight DiagnosticVirtualTextError guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextWarn guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextInfo guibg=none]])
      vim.cmd([[highlight DiagnosticVirtualTextHint guibg=none]])
      vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
        border = "rounded",
      })
    end,
  },
}
