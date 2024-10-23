return {
  "lepture/vim-jinja",
  config = function()
    vim.cmd("hi jinjaVarBlock guifg=#cdd6f4")
    vim.cmd("hi jinjaTagBlock guifg=#cdd6f4")
    vim.cmd("hi jinjaArgument guifg=#94e2d5")
    vim.cmd("hi jinjaStatement guifg=#cba6f7")
    vim.cmd("hi htmlTagName guifg=#89b4fa")
    vim.cmd("hi htmlTag guifg=#94e2d5")
    vim.cmd("hi htmlEndTag guifg=#94e2d5")
  end,
}
