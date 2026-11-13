-- Look & layout: Nord theme (transparent, like hendrikmi/dotfiles) + neo-tree on the left
return {
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.nord_contrast = true
      vim.g.nord_borders = false
      vim.g.nord_disable_background = true -- let WezTerm's translucent background show through
      vim.g.nord_italic = false
      vim.g.nord_bold = false
      vim.g.nord_uniform_diff_background = true
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "nord" } },

  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      window = {
        position = "left",
        width = 34,
        mappings = {
          ["<Tab>"] = "next_source", -- Tab flips Files <-> Git
          ["<S-Tab>"] = "prev_source",
        },
      },
      -- Tab bar at the top of the tree: Files | Git
      sources = { "filesystem", "git_status" },
      source_selector = {
        winbar = true,
        content_layout = "center",
        sources = {
          { source = "filesystem", display_name = " 󰉓 Files " },
          { source = "git_status", display_name = " 󰊢 Git " },
        },
      },
      git_status = { window = { position = "left" } },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_by_name = { ".git", "node_modules", "__pycache__", ".venv" },
        },
      },
      default_component_configs = {
        indent = { with_markers = true },
      },
    },
  },

  -- Open the tree on the left at startup (cursor stays in the editor)
  {
    "nvim-neo-tree/neo-tree.nvim",
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if vim.o.columns < 100 then return end
          vim.schedule(function()
            pcall(vim.cmd, "Neotree show left")
          end)
        end,
      })
    end,
  },

  { "nvim-lualine/lualine.nvim", opts = { options = { theme = "nord" } } },

  -- Snappier smooth-scroll (default animation made fast movement feel laggy)
  { "folke/snacks.nvim", opts = { scroll = { animate = { duration = { step = 10, total = 80 } } } } },
}
