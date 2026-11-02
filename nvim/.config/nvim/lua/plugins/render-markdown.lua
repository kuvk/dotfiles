-- Renders markdown in the buffer; the line under the cursor shows its source.
-- <leader>mp toggles it (config/keymaps.lua).
return {
  "MeanderingProgrammer/render-markdown.nvim",
  ft = { "markdown" },
  cmd = { "RenderMarkdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {},
}
