return {
  "vim-test/vim-test",
  dependencies = {
    "preservim/vimux",
  },
  cmd = { "TestNearest", "TestFile" },
  config = function()
    vim.g["test#strategy"] = "vimux"
  end,
}
