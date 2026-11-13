return {
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup({
        suppressed_dirs = { "~/", "~/projects", "~/Downloads", "~/src" },
        auto_restore = false,
        -- Telescope loads when the session picker opens (:AutoSession search), not at startup
        session_lens = { load_on_setup = false },
      })
    end,
  },
}
