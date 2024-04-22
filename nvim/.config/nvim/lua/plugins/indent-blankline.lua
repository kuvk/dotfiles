return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPre", "BufNewFile" },
  main = "ibl",
  enabled = true,
  lazy = true,
  opts = {
    scope = { enabled = false },
  },
}
