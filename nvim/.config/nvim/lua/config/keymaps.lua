-- Every keybinding, each with a description. <leader>? searches them in a window.
-- Keys that only work inside a plugin's own window stay with that plugin
-- (Neo-tree in neo-tree.lua, completion in completions.lua).
vim.g.mapleader = " "
vim.g.tmux_navigator_no_mappings = 1

local map = vim.keymap.set

-- Keybindings window
map("n", "<leader>?", "<cmd>Telescope keymaps<CR>", { desc = "Search keybindings" })

-- Insert mode
map("i", "jk", "<ESC>", { desc = "Leave insert mode" })

-- Clipboard: y, d and p use the system clipboard (options.lua). Small edits stay
-- out of it, and of the clipboard history
for _, key in ipairs({ "x", "X", "c", "C" }) do
  map({ "n", "x" }, key, '"_' .. key, { desc = key .. " without copying" })
end
map("n", "s", '"_s', { desc = "Substitute without copying" })
map({ "n", "x" }, "<leader>d", '"_d', { desc = "Delete without copying" })
map("x", "p", "P", { desc = "Paste over selection, keeping the clipboard" })

-- Windows and tmux panes
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "Go to left split or tmux pane" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "Go to lower split or tmux pane" })
map("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "Go to upper split or tmux pane" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "Go to right split or tmux pane" })
map("n", "<C-\\>", "<cmd>TmuxNavigatePrevious<CR>", { desc = "Go to previous split or tmux pane" })
map("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
map("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })
map("n", "<C-Left>", "<cmd>vertical resize +5<CR>", { desc = "Resize split wider" })
map("n", "<C-Down>", "<cmd>resize -5<CR>", { desc = "Resize split shorter" })
map("n", "<C-Up>", "<cmd>resize +5<CR>", { desc = "Resize split taller" })
map("n", "<C-Right>", "<cmd>vertical resize -5<CR>", { desc = "Resize split narrower" })

-- Tabs
map("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
map("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
map("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
map("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
map("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- Buffers
map("n", "<leader>co", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close other buffers" })
map("n", "<leader>,", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
map("n", "<leader>.", "<cmd>BufferLineCycleNext<CR>", { desc = "Next buffer" })

-- Save and quit
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>W", "<cmd>wa<CR>", { desc = "Save all files" })
map("n", "<leader>q", "<cmd>qa<CR>", { desc = "Quit" })
map("n", "<leader>Q", "<cmd>qa!<CR>", { desc = "Quit without saving" })

-- Editing
map("n", "<leader>o", "o<ESC>", { desc = "Add line below" })
map("n", "<leader>O", "O<ESC>", { desc = "Add line above" })
map("n", "<leader>nh", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>ti", "<cmd>IBLToggle<CR>", { desc = "Toggle indent guides" })

-- Files
map("n", "<C-n>", "<cmd>Neotree toggle<CR>", { desc = "Toggle file tree" })
map("n", "<C-f>", "<cmd>Neotree focus<CR>", { desc = "Focus file tree" })
map("n", "<leader>ff", "<cmd>Telescope find_files hidden=true<CR>", { desc = "Find files" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Find recent files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Find text in files" })
map("n", "<leader>fc", "<cmd>Telescope grep_string<CR>", { desc = "Find word under cursor" })
map("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find todos" })

-- Sessions
map("n", "<leader>Ss", "<cmd>AutoSession save<CR>", { desc = "Save session" })
map("n", "<leader>Sr", "<cmd>AutoSession restore<CR>", { desc = "Restore session" })
map("n", "<leader>Sa", "<cmd>AutoSession search<CR>", { desc = "Search sessions" })

-- Git
map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", { desc = "Preview git change" })
map("n", "<leader>lg", "<cmd>LazyGit<CR>", { desc = "Open LazyGit" })

-- Code
map("n", "<leader>gf", function()
  vim.lsp.buf.format({
    filter = function(client)
      return client.name == "null-ls"
    end,
    timeout_ms = 3200,
  })
end, { desc = "Format file" })
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Toggle diagnostics list" })
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local function lsp(modes, lhs, rhs, desc)
      map(modes, lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    lsp("n", "K", vim.lsp.buf.hover, "Show documentation")
    lsp("n", "<leader>gd", vim.lsp.buf.definition, "Go to definition")
    lsp("n", "<leader>gr", vim.lsp.buf.references, "Show references")
    lsp({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
  end,
})

-- Debugger
local function dap(action)
  return function()
    require("dap")[action]()
  end
end
map("n", "<leader>Db", dap("toggle_breakpoint"), { desc = "Toggle breakpoint" })
map("n", "<leader>Dc", dap("continue"), { desc = "Start or continue debugging" })
map("n", "<leader>Dd", dap("step_over"), { desc = "Step over" })
map("n", "<leader>Do", dap("step_out"), { desc = "Step out" })
map("n", "<leader>Di", dap("step_into"), { desc = "Step into" })
map("n", "<leader>Dt", dap("terminate"), { desc = "Stop debugging" })

-- Tools
map("n", "<leader>mp", "<cmd>RenderMarkdown toggle<CR>", { desc = "Toggle markdown rendering" })
-- Previews the current file, or stops if that's the one being previewed. Each start gets
-- a free port, so other Neovims and browser tabs of an earlier preview can't get in the way.
local previewed_file
map("n", "<leader>mb", function()
  local file = vim.api.nvim_buf_get_name(0)
  if require("livepreview").is_running() and file == previewed_file then
    vim.cmd.LivePreview("close")
    return
  end
  local socket = vim.uv.new_tcp()
  socket:bind("127.0.0.1", 0)
  local port = socket:getsockname().port
  socket:close()
  require("livepreview.config").set({ port = port, dynamic_root = true })
  vim.cmd.LivePreview("start")
  previewed_file = file
end, { desc = "Preview markdown file in browser, or stop" })
map("n", "<leader>mm", "<cmd>Mason<CR>", { desc = "Open Mason" })
map("n", "<leader>ll", "<cmd>Lazy<CR>", { desc = "Open Lazy" })
