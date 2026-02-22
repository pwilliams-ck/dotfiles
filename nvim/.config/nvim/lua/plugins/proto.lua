return {
  -- Add treesitter support for proto
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, { "proto" })
      end
    end,
  },

  -- Configure formatting
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        proto = { "buf" }, -- or "clang-format" if you prefer
      },
    },
  },

  -- Optional: Add LSP support
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bufls = {}, -- This adds buf LSP support
      },
    },
  },
}
