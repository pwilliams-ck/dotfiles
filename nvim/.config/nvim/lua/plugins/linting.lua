return {
  -- markdownlint-cli2 is fed the buffer over stdin, so it resolves config from
  -- Neovim's cwd (not the file's dir) and won't walk up to $HOME. Pass the home
  -- config explicitly so ~/.markdownlint.json applies in every project, not just
  -- when nvim is launched from $HOME.
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", vim.fn.expand("~/.markdownlint.json") },
        },
      },
    },
  },
}
