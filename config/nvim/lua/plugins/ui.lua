-- UI polish: colorscheme + statusline. ENABLED — set `enabled = false` on a
-- spec to turn it back off.
-- (Treesitter, which is also "UI", lives in its own file: treesitter.lua.)
return {
  ----------------------------------------------------------------------------
  -- Colorscheme: vscode.nvim — built to mirror VS Code's default dark theme
  -- (Dark+/Dark Modern share the same core palette), so it should feel just
  -- like your editor: same blues, oranges, teals. Rich treesitter + LSP
  -- semantic-token highlighting.
  -- NOTE: keep exactly ONE colorscheme spec enabled. tokyonight is kept below,
  -- disabled, as an easy alternative.
  ----------------------------------------------------------------------------
  {
    "Mofiqul/vscode.nvim",
    priority = 1000,             -- load the colorscheme before other UI plugins
    opts = {
      italic_comments = true,
      underline_links = true,
      terminal_colors = true,    -- recolor :terminal windows to match
      -- transparent = true,     -- uncomment to use your terminal's background
    },
    config = function(_, opts)
      vim.o.background = "dark"
      require("vscode").setup(opts)
      vim.cmd.colorscheme("vscode")
    end,
  },

  -- Alternative: tokyonight. To use it, set enabled = true and disable vscode.
  {
    "folke/tokyonight.nvim",
    enabled = false, -- set to true to enable (and disable the others)
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  ----------------------------------------------------------------------------
  -- Statusline — the bottom bar: mode, git branch, diagnostics, file info.
  -- (mini.statusline is a lighter alternative if you want fewer deps.)
  ----------------------------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    enabled = true, -- set to false to disable
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "auto",
        globalstatus = true, -- one statusline shared across all splits
        section_separators = "",
        component_separators = "|",
      },
    },
  },

  ----------------------------------------------------------------------------
  -- Indent guides — faint vertical lines marking indent levels (like VS Code).
  ----------------------------------------------------------------------------
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
    },
  },

  ----------------------------------------------------------------------------
  -- bufferline — open buffers as tabs along the top (VS Code editor tabs).
  -- <S-h>/<S-l> cycle them (overriding the plain bnext/bprev in keymaps.lua).
  ----------------------------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    keys = {
      { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
      { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Prev buffer" },
      { "<leader>bp", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
      { "<leader>bd", "<cmd>BufferLinePickClose<CR>", desc = "Pick buffer to close" },
    },
    opts = {
      options = {
        diagnostics = "nvim_lsp",            -- show LSP errors/warnings on the tabs
        always_show_bufferline = true,
        offsets = {
          { filetype = "neo-tree", text = "Explorer", separator = true },
        },
      },
    },
  },
}
