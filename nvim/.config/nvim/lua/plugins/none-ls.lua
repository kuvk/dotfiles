return {
  "nvimtools/none-ls.nvim",
  dependencies = {
    "nvimtools/none-ls-extras.nvim",
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
        "cpptools",
        "clang-format",
      },
    })
    local null_ls = require("null-ls")
    null_ls.setup({
      sources = {
        require("none-ls.formatting.beautysh"),
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
          filetypes = { "django", "jinja", "htmldjango" },
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
        null_ls.builtins.diagnostics.djlint.with({ filetypes = { "django", "jinja", "htmldjango" } }),
        -- C/C++. Style comes from the project's .clang-format, if it has one
        null_ls.builtins.diagnostics.cppcheck,
        null_ls.builtins.formatting.clang_format,

        -- Prettier
        null_ls.builtins.formatting.prettier.with({
          -- Prettier skips anything in .gitignore by default; only .prettierignore here
          extra_args = { "--ignore-path", ".prettierignore" },
          disabled_filetypes = {
            "htmldjango",
            "jinja",
          },
        }),

        -- Python formatting: isort, then Black. Ruff is a language server (lsp-config.lua)
        null_ls.builtins.formatting.isort,
        null_ls.builtins.formatting.black,
        -- Qt 6's, as /usr/bin/qmlformat is Qt 5's and has no indent option
        null_ls.builtins.formatting.qmlformat.with({
          command = "/usr/lib/qt6/bin/qmlformat",
          extra_args = { "--indent-width", "2" },
        }),

      },
    })
  end,
}
