-- File navigation:
--   * neo-tree   — persistent Explorer sidebar (toggle <leader>e).
--   * yazi.nvim  — the full yazi file manager in a floating window (<leader>y):
--                  browse, then press Enter to open the file IN this editor;
--                  close the float to hide it ("minimize"). This is the reliable
--                  way to open files from yazi in the editor — running yazi as a
--                  separate zellij pane can't hand a file to a running nvim
--                  without fragile RPC wiring.
return {
  ----------------------------------------------------------------------------
  -- neo-tree.nvim — Explorer sidebar (VS Code's Explorer panel).
  ----------------------------------------------------------------------------
  {
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
  },

  ----------------------------------------------------------------------------
  -- yazi.nvim — yazi file manager inside nvim. <leader>y opens it on the current
  -- file; navigate and press Enter to open the selection in this editor; close
  -- the float to hide it. Needs the `yazi` binary (install_deps.sh installs it).
  ----------------------------------------------------------------------------
  {
    "mikavilpas/yazi.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>y", "<cmd>Yazi<CR>", desc = "Yazi (at current file)" },
      { "<leader>Y", "<cmd>Yazi cwd<CR>", desc = "Yazi (working dir)" },
      { "<leader>yr", "<cmd>Yazi toggle<CR>", desc = "Resume last Yazi" },
    },
    opts = {
      open_for_directories = false, -- keep neo-tree for opening directories
    },
  },
}
