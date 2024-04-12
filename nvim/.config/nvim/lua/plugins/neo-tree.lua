return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("neo-tree").setup({
      close_if_last_window = true,
      -- popup_border_style = "rounded", -- "double", "none", "rounded", "shadow", "single" or "solid"
      default_component_configs = {
        diagnostics = {
          symbols = {
            hint = "󰌵 ",
            warn = " ",
            info = " ",
            error = " ",
          },
          highlights = {
            hint = "DiagnosticSignHint",
            info = "DiagnosticSignInfo",
            warn = "DiagnosticSignWarn",
            error = "DiagnosticSignError",
          },
        },
        -- git_status = {
        --   symbols = {
        --     -- Change type
        --     added     = "✚", -- NOTE: you can set any of these to an empty string to not show them
        --     deleted   = "✖",
        --     modified  = "",
        --     renamed   = "",
        --     -- Status type
        --     untracked = "",
        --     ignored   = "",
        --     unstaged  = "",
        --     staged    = "",
        --     conflict  = "",
        --   },
        --   align = "right",
        -- },
        indent = {
          with_markers = false,
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = "",
          -- padding = 2,
        },
      },
      window = {
        position = "left",
        auto_expand_width = false,
        width = 40,
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false,
          always_show = { -- remains visible even if other settings would normally hide it
            ".gitignored",
          },
          never_show = { -- remains hidden even if visible is toggled to true, this overrides always_show
            ".DS_Store",
            "thumbs.db",
          },
        },
        follow_current_file = {
          enabled = true,
          leave_dirs_open = true,
        },
      },
    })
    vim.keymap.set("n", "<C-n>", ":Neotree toggle<CR>", {})
    vim.keymap.set("n", "<C-f>", ":Neotree focus<CR>", {})
  end,
}
