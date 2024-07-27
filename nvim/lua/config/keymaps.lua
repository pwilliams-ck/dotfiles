-- keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local keymap = vim.keymap
local opts = { noremap = true, silent = true }

local discipline = require("pwilliams.discipline")
discipline.cowboy()

-- Increment/decrement
-- keymap.set("n", "+", "<C-a>")
-- keymap.set("n", "-", "<C-x>")

-- Delete a word backwards
keymap.set("n", "dw", "db")

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- Jumplist
keymap.set("n", "<C-m>", "<C-i>", opts)

-- New tab
keymap.set("n", "te", ":tabedit<Return>", opts)
keymap.set("n", "<tab>", ":tabnext<Return>", opts)
keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)

-- Split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)

-- Move window
keymap.set("n", "sh", "<C-w>h")
keymap.set("n", "sk", "<C-w>k")
keymap.set("n", "sj", "<C-w>j")
keymap.set("n", "sl", "<C-w>l")

-- Resize window
keymap.set("n", "<C-w><left>", "<C-w><")
keymap.set("n", "<C-w><right>", "<C-w>>")
keymap.set("n", "<C-w><up>", "<C-w>+")
keymap.set("n", "<C-w><down>", "<C-w>-")

-- Diagnostics
keymap.set("n", "<C-j>", function()
  vim.diagnostic.goto_next()
end, opts)
keymap.set("n", "<C-l>", function()
  vim.diagnostic.goto_prev()
end, opts)

-- Leader key
vim.g.mapleader = " "

-- Make file exeucutable
keymap.set("n", "<leader>fx", ":!chmod +x %<Return>")

-- tmux seshs
keymap.set("n", "<leader>t", ":!tmux neww tmux-seshs.sh<Return>")

-- harpoon
local harpoon = require("harpoon")

harpoon:setup()

keymap.set("n", "ha", function()
  harpoon:list():add()
end)
keymap.set("n", "<C-p>", function()
  harpoon:list():prev()
end)
keymap.set("n", "<C-y>", function()
  harpoon:list():next()
end)
