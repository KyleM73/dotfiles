-- Editing quality-of-life. DISABLED by default — flip `enabled` to true and
-- restart nvim to turn these on. Both are lightweight and highly recommended.
return {
  ----------------------------------------------------------------------------
  -- which-key — press <leader> (or any prefix) and a popup lists every keybind
  -- under it, using the `desc` strings throughout this config. Great for
  -- discovering and remembering mappings.
  ----------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    enabled = false, -- <-- flip to true to enable
    event = "VeryLazy",
    opts = {},
  },

  ----------------------------------------------------------------------------
  -- autopairs — auto-insert the closing ) ] } " ' as you type.
  ----------------------------------------------------------------------------
  {
    "windwp/nvim-autopairs",
    enabled = false, -- <-- flip to true to enable
    event = "InsertEnter",
    opts = {},
  },
}
