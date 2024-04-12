return {
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        auto_session_suppress_dirs = { "~/", "~/projects", "~/Downloads", "~/src" },
        auto_restore_enabled = false,
        session_lens = {
          -- If load_on_setup is set to false, one needs to eventually call `require("auto-session").setup_session_lens()` if they want to use session-lens.
          -- buftypes_to_ignore = {}, -- list of buffer types what should not be deleted from current session
          -- load_on_setup = true,
          -- theme_conf = { border = true },
          -- previewer = false,
        },
      })
      vim.keymap.set("n", "<leader>ws", ":SessionSave<CR>", {})
      vim.keymap.set("n", "<leader>wr", ":SessionRestore<CR>", {})
      vim.keymap.set("n", "<leader>wa", require("auto-session.session-lens").search_session, {
        noremap = true,
      })
    end,
  },
}
