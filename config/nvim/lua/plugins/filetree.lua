-- neo-tree.nvim — file explorer sidebar (VSCode's "Explorer" panel).
-- ACTIVE. Toggle with <leader>e. Shows git status; supports add / rename /
-- delete / move from the tree.
return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    -- Icons want a Nerd Font (vim.g.have_nerd_font). If you don't have one,
    -- remove this dependency — neo-tree falls back to plain text fine.
    "nvim-tree/nvim-web-devicons",
  },
  cmd = "Neotree",
  keys = {
    { "<leader>e", "<cmd>Neotree toggle<CR>", desc = "Explorer (neo-tree)" },
    { "<leader>o", "<cmd>Neotree focus<CR>", desc = "Focus explorer" },
  },
  opts = {
    close_if_last_window = true, -- don't leave nvim showing only the tree
    enable_git_status = true,
    enable_diagnostics = true,
    filesystem = {
      follow_current_file = { enabled = true }, -- reveal the file you're editing
      use_libuv_file_watcher = true,            -- auto-refresh on disk changes
      filtered_items = {
        visible = true,        -- show hidden / gitignored files (dimmed)
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
    window = {
      width = 32,
      mappings = {
        ["<Esc>"] = "cancel",
        ["P"] = { "toggle_preview", config = { use_float = true } },
      },
    },
  },
}
