-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

-- Turn off paste mode when leaving insert
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  command = "set nopaste",
})

-- Semantic line breaks for prose: never hard-wrap; soft-wrap the display
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit", "asciidoc" },
  callback = function()
    vim.opt_local.textwidth = 0 -- no auto hard-wrap column
    vim.opt_local.wrap = true -- soft-wrap long lines visually
    vim.opt_local.linebreak = true -- break at word, not mid-word
    vim.opt_local.breakindent = true -- keep indent on wrapped lines
    -- Drop auto-wrap flags so typing/reflow never inserts breaks
    vim.opt_local.formatoptions:remove({ "t", "c" })
    -- Move by screen line, so j/k feel natural on wrapped prose
    vim.keymap.set({ "n", "x" }, "j", "gj", { buffer = true })
    vim.keymap.set({ "n", "x" }, "k", "gk", { buffer = true })
    -- Uncomment after `pip install sembr` to reflow paragraphs with gqip:
    -- vim.opt_local.formatprg = "sembr"
  end,
})

-- Fix conceallevel for json files
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc", "markdown", "typescript", "javascript", "python" },
  callback = function()
    vim.wo.spell = false
    vim.wo.conceallevel = 0
  end,
})
