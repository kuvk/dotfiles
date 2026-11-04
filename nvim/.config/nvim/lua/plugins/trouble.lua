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
    modes = {
      -- Only problems in open buffers, not every file the language server checked
      diagnostics = {
        filter = function(items)
          return vim.tbl_filter(function(item)
            return item.buf and vim.api.nvim_buf_is_loaded(item.buf) and vim.bo[item.buf].buflisted
          end, items)
        end,
      },
    },
  },
}
