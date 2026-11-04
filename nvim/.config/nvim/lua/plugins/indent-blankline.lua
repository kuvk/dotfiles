return {
  "lukas-reineke/indent-blankline.nvim",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "IBLToggle" },
  main = "ibl",
  enabled = true,
  lazy = true,
  opts = {
    indent = {
      char = "▏",
    },
    -- Only the guide of the block the cursor is in is colored (IblScope, theme.lua), in the
    -- same thin character; no underline where it starts or ends
    scope = {
      enabled = true,
      show_start = false,
      show_end = false,
    },
  },
}
