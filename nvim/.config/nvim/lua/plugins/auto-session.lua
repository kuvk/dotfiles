return {
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        suppressed_dirs = { "~/", "~/projects", "~/Downloads", "~/src" },
        auto_restore = false,
        -- session_lens = {
        -- If load_on_setup is set to false, one needs to eventually call `require("auto-session").setup_session_lens()` if they want to use session-lens.
        -- buftypes_to_ignore = {}, -- list of buffer types what should not be deleted from current session
        -- load_on_setup = true,
        -- theme_conf = { border = true },
        -- previewer = false,
        -- },
      })
      vim.keymap.set("n", "<leader>ws", ":AutoSession save<CR>", {})
      vim.keymap.set("n", "<leader>wr", ":AutoSession restore<CR>", {})
      vim.keymap.set("n", "<leader>wa", ":AutoSession search<CR>", {})
    end,
  },
}
