return {
  "nvimtools/none-ls.nvim",
  dependencies = {
    "nvimtools/none-ls-extras.nvim",
    "gbprod/none-ls-shellcheck.nvim",
    "jay-babu/mason-null-ls.nvim",
  },
  config = function()
    require("mason-null-ls").setup({
      ensure_installed = {
        "stylua",
        "prettier",
        "djlint",
        "isort",
        "black",
        "ruff",
        "beautysh",
        "debugpy",
      },
    })
    local null_ls = require("null-ls")
    null_ls.setup({
      sources = {
        require("none-ls.formatting.beautysh"),
        -- Shellcheck diagnostics not neccessary if using bashls
        -- require("none-ls-shellcheck.diagnostics"),
        -- require("none-ls-shellcheck.code_actions"),
        -- null_ls.builtins.formatting.shfmt.with({
        --   extra_args = {
        --     "-i",
        --     "4",
        --   },
        -- }),
        null_ls.builtins.formatting.stylua.with({
          extra_args = {
            "--indent-type",
            "Spaces",
            "--indent-width",
            "2",
          },
        }),
        -- Jinja formatting setup
        null_ls.builtins.formatting.djlint.with({
          extra_args = {
            "--indent",
            "2",
            "--max-blank-lines",
            "1",
            "--max-attribute-length",
            "20",
            "--profile",
            "jinja",
            "--quiet",
          },
        }),
        null_ls.builtins.diagnostics.djlint,
        -- C/C++ setup with cppcheck and astyle (installed manually)
        null_ls.builtins.diagnostics.cppcheck,
        null_ls.builtins.formatting.astyle,

        -- Prettier
        null_ls.builtins.formatting.prettier.with({
          -- Prettier skips anything in .gitignore by default; only .prettierignore here
          extra_args = { "--ignore-path", ".prettierignore" },
          disabled_filetypes = {
            "htmldjango",
            "jinja.html",
          },
        }),

        -- Python formatting: isort, then Black. Ruff is a language server (lsp-config.lua)
        null_ls.builtins.formatting.isort,
        null_ls.builtins.formatting.black,
				null_ls.builtins.formatting.qmlformat,

      },
    })

    local lsp_formatting = function(bufnr)
      vim.lsp.buf.format({
        filter = function(client)
          return client.name == "null-ls"
        end,
        bufnr = bufnr,
        timeout_ms = 3200,
      })
    end

    vim.keymap.set("n", "<leader>gf", function()
      lsp_formatting(0)
    end)
  end,
}
