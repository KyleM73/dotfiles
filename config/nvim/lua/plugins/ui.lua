-- UI polish: colorscheme + statusline. DISABLED by default — flip
-- `enabled = false` -> `true` on a spec and restart nvim to turn it on.
-- (Treesitter, which is also "UI", lives in its own file: treesitter.lua.)
return {
  ----------------------------------------------------------------------------
  -- Colorscheme. tokyonight has excellent true-color/ghostty support.
  -- Alternatives: "catppuccin/nvim", "ellisonleao/gruvbox.nvim", or
  -- "mhartington/oceanic-next" to match your old vim colorscheme.
  ----------------------------------------------------------------------------
  {
    "folke/tokyonight.nvim",
    enabled = false, -- <-- flip to true to enable
    priority = 1000, -- load the colorscheme before other UI plugins
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
    enabled = false, -- <-- flip to true to enable
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
}
