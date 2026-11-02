return {
  "vim-test/vim-test",
  dependencies = {
    "preservim/vimux",
  },
  keys = {
    { "<leader>nt", "<cmd>TestNearest<CR>" },
    { "<leader>T", "<cmd>TestFile<CR>" },
  },
  config = function()
    vim.g["test#strategy"] = "vimux"
  end,
}
