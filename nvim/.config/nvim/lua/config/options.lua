-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Only run Prettier in projects that have a Prettier config (respects each repo's intent)
vim.g.lazyvim_prettier_needs_config = true

vim.opt.mouse = ""

-- Undercurl
vim.cmd([[let &t_Cs = "\e[4:3m"]])
vim.cmd([[let &t_Ce = "\e[4:0m"]])

-- GUI Cursor
vim.opt.guicursor = "n-v-c-sm:block,i-ci:blinkwait300-blinkon200-blinkoff150"

-- Tabs and spaces (default 2; ftplugin/ overrides per language)
vim.opt.tabstop = 2
vim.opt.expandtab = true
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
