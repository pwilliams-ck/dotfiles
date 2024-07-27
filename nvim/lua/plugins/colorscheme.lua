return {
  -- Set Tokyo Night Storm as the default
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "onedark", -- set this to your preferred colorscheme,
    },
  },

  -- onedark
  {
    "navarasu/onedark.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      style = "dark", -- Options: dark, darker, cool, deep, warm, warmer
      transparent = false, -- Enable this to disable setting the background color
      term_colors = false, -- Configure terminal colors (vim.g.terminal_color_*)
      ending_tildes = false, -- Show the end-of-buffer tildes
      cmp_itemkind_reverse = false, -- Reverse item kind highlights in cmp menu

      -- Toggle theme style components
      -- toggle_style_key = "<leader>ts", -- Keybind to toggle theme style
      -- toggle_style_list = { "dark", "darker", "cool", "deep", "warm", "warmer" },

      -- change code style
      -- Options are italic, bold, underline, none
      -- You can configure multiple style with comma separated, For e.g., keywords = 'italic,bold'
      code_style = {
        comments = "italic",
        keywords = "none",
        functions = "bold",
        strings = "none",
        variables = "none",
      },

      -- Plugins Config
      diagnostics = {
        darker = true, -- darker colors for diagnostic
        undercurl = true, -- use undercurl instead of underline for diagnostics
        background = true, -- use background color for virtual text
      },
    },
  },

  -- Tokyo Night
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      style = "night", -- Options: storm, night, day, moon
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  -- Solarized Osaka
  {
    "craftzdog/solarized-osaka.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      transparent = true,
    },
  },

  -- Nightfly
  { "bluz71/vim-nightfly-colors", name = "nightfly", lazy = true, priority = 1000 },

  -- Cyberpunk Neon
  { "Roboron3042/Cyberpunk-Neon", name = "cyberpunk", lazy = true, priority = 1000 },

  -- Jungle theme (using Everforest as an example)
  {
    "sainnhe/everforest",
    lazy = true,
    priority = 1000,
    config = function()
      vim.g.everforest_background = "hard"
      vim.g.everforest_better_performance = 1

      -- Additional settings
      vim.g.everforest_transparent_background = 1 -- Enable transparent background
      vim.g.everforest_disable_italic_comment = 1 -- Disable italics in comments
      vim.g.everforest_diagnostic_text_highlight = 1 -- Enable diagnostic text highlight
      vim.g.everforest_diagnostic_line_highlight = 1 -- Enable diagnostic line highlight
      vim.g.everforest_sign_column_background = "none" -- Sign column background
      vim.g.everforest_enable_sidebar_background = 1 -- Enable contrast sidebars
      vim.g.everforest_float_style = "bright" -- Floating window style
    end,
  },

  -- Some other cool themes:

  -- Catppuccin (customizable pastel theme)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha", -- Options: latte, frappe, macchiato, mocha
      background = { dark = "mocha", light = "latte" },
      transparent_background = true,
    },
  },

  -- Dracula (dark theme with vibrant colors)
  { "Mofiqul/dracula.nvim", lazy = true, priority = 1000 },

  -- Nord (arctic, north-bluish color palette)
  { "shaunsingh/nord.nvim", lazy = true, priority = 1000 },

  -- Gruvbox Material (retro groove color scheme)
  {
    "sainnhe/gruvbox-material",
    lazy = true,
    priority = 1000,
    config = function()
      vim.g.gruvbox_material_background = "hard"
      vim.g.gruvbox_material_better_performance = 1
    end,
  },
}
