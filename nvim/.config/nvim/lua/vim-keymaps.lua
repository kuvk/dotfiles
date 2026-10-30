vim.g.mapleader = " "

local keymap = vim.keymap

keymap.set("i", "jk", "<ESC>")

-- Clipboard: y, d and p use the system clipboard (vim-options.lua). Small edits
-- stay out of it, and of the clipboard history
for _, key in ipairs({ "x", "X", "c", "C" }) do
  keymap.set({ "n", "x" }, key, '"_' .. key)
end
keymap.set("n", "s", '"_s')
keymap.set({ "n", "x" }, "<leader>d", '"_d', { desc = "Delete without copying" })
-- Pasting over a selection keeps the clipboard, so it can be pasted again
keymap.set("x", "p", "P")

-- Manage split windows
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })
keymap.set("n", "<C-Left>", ":vertical resize +5<CR>")
keymap.set("n", "<C-Down>", ":resize -5<CR>")
keymap.set("n", "<C-Up>", ":resize +5<CR>")
keymap.set("n", "<C-Right>", ":vertical resize -5<CR>")

-- Tabs
keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })                     -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })              -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })                     --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })                 --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- Close and Save
keymap.set("n", "<leader>q", ":qa<CR>")
keymap.set("n", "<leader>w", ":w<CR>")
keymap.set("n", "<leader>Q", ":qa!<CR>")
keymap.set("n", "<leader>W", ":wa<CR>")

-- New line
keymap.set("n", "<leader>o", "o<ESC>")
keymap.set("n", "<leader>O", "O<ESC>")

-- Remove highlighted search
keymap.set("n", "<leader>nh", ":nohlsearch<CR>")

-- Markdown Preview
keymap.set("n", "<leader>mp", ":MarkdownPreviewToggle<CR>")
keymap.set("n", "<leader>ll", ":Lazy<CR>")
