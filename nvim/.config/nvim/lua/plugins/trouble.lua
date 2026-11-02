return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    focus = true,
    -- A small split under the file, leaving the file tree full height
    win = {
      type = "split",
      relative = "win",
      position = "bottom",
      size = 10,
    },
  },
}
