require "nvchad.mappings" -- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

map("n", "<C-H>", "<cmd> TmuxNavigateLeft<CR>", { desc = "Tmux Navigate Left" })
map("n", "<C-J>", "<cmd> TmuxNavigateDown<CR>", { desc = "Tmux Navigate Down" })
map("n", "<C-K>", "<cmd> TmuxNavigateUp<CR>", { desc = "Tmux Navigate Up" })
map("n", "<C-L>", "<cmd> TmuxNavigateRight<CR>", { desc = "Tmux Navigate Right" })
