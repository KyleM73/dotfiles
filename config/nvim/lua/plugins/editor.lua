-- Editing quality-of-life. ENABLED — set `enabled = false` on a spec to turn
-- it back off. Both are lightweight and highly recommended.
return {
  ----------------------------------------------------------------------------
  -- which-key — press <leader> (or any prefix) and a popup lists every keybind
  -- under it, using the `desc` strings throughout this config. Great for
  -- discovering and remembering mappings.
  ----------------------------------------------------------------------------
  {
    "folke/which-key.nvim",
    enabled = true, -- set to false to disable
    event = "VeryLazy",
    opts = {},
  },

  ----------------------------------------------------------------------------
  -- autopairs — auto-insert the closing ) ] } " ' as you type.
  ----------------------------------------------------------------------------
  {
    "windwp/nvim-autopairs",
    enabled = true, -- set to false to disable
    event = "InsertEnter",
    opts = {},
  },
}
