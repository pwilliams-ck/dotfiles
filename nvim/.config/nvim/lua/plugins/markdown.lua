-- Make the markdown-preview.nvim browser preview mirror github.com's rendering.
-- `mkdp_markdown_css` replaces the plugin's markdown.css wholesale, so concatenate
-- upstream with css/mkdp-github.css and regenerate whenever either side changes.
local upstream = vim.fn.stdpath("data") .. "/lazy/markdown-preview.nvim/app/_static/markdown.css"
local overrides = vim.fn.stdpath("config") .. "/css/mkdp-github.css"
local generated = vim.fn.stdpath("cache") .. "/mkdp-github.css"

local function newest_source_mtime()
  local newest = 0
  for _, path in ipairs({ upstream, overrides }) do
    local stat = vim.uv.fs_stat(path)
    if not stat then
      return nil
    end
    newest = math.max(newest, stat.mtime.sec)
  end
  return newest
end

local function github_css()
  local newest = newest_source_mtime()
  if not newest then
    return nil
  end

  local out = vim.uv.fs_stat(generated)
  if not out or out.mtime.sec < newest then
    -- One string per line: writefile() turns embedded newlines into NUL bytes.
    local css = vim.fn.readfile(upstream)
    vim.list_extend(css, vim.fn.readfile(overrides))
    vim.fn.writefile(css, generated)
  end

  return generated
end

return {
  {
    "iamcco/markdown-preview.nvim",
    init = function()
      vim.g.mkdp_markdown_css = github_css() or ""

      -- Plugin defaults, minus the markdown-it typographer: GitHub does not
      -- curl quotes or dashes, so smart punctuation shows up as a diff.
      vim.g.mkdp_preview_options = {
        mkit = { typographer = false },
        katex = {},
        uml = {},
        maid = {},
        disable_sync_scroll = 0,
        sync_scroll_type = "middle",
        hide_yaml_meta = 1,
        sequence_diagrams = {},
        flowchart_diagrams = {},
        content_editable = false,
        disable_filename = 0,
        toc = {},
      }
    end,
  },
}
