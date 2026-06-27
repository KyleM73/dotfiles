-- Editing, navigation & workflow quality-of-life. All ENABLED — set
-- `enabled = false` on any spec to turn it back off.
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

  ----------------------------------------------------------------------------
  -- vim-sleuth — auto-detect indentation (shiftwidth / expandtab) per file, so
  -- you match each project's existing style automatically (VS Code does this).
  ----------------------------------------------------------------------------
  { "tpope/vim-sleuth", event = { "BufReadPre", "BufNewFile" } },

  ----------------------------------------------------------------------------
  -- todo-comments — highlight and jump between TODO / FIXME / HACK / NOTE / WARN.
  ----------------------------------------------------------------------------
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    opts = { signs = true },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO comment" },
      { "<leader>ft", "<cmd>TodoQuickFix<CR>", desc = "List TODOs (quickfix)" },
    },
  },

  ----------------------------------------------------------------------------
  -- trouble.nvim — a navigable list panel for diagnostics, symbols, quickfix,
  -- and todos. <leader>xx is the "Problems" view: every LSP error/warning in
  -- one list (Enter jumps to it). <leader>x is the Trouble prefix.
  ----------------------------------------------------------------------------
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = { focus = true },
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Diagnostics: workspace (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Diagnostics: this buffer" },
      { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<CR>", desc = "Symbols outline" },
      { "<leader>xl", "<cmd>Trouble loclist toggle<CR>", desc = "Location list" },
      { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
      { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "Todos" },
    },
  },

  ----------------------------------------------------------------------------
  -- flash.nvim — jump anywhere on screen fast: press `s`, type 1-2 chars of the
  -- target, then the one-key label that appears on each match. Works with
  -- operators (e.g. `d` then `s`+target) and `S` jumps by treesitter node.
  -- NOTE: this remaps `s` (normally "substitute"); use `cl` for that instead.
  ----------------------------------------------------------------------------
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle flash search" },
    },
  },

  ----------------------------------------------------------------------------
  -- persistence.nvim — per-directory sessions: saves your open buffers, splits,
  -- and tabpages so they return when you reopen nvim in that project. This is
  -- the EDITOR half of "reopen my workspace"; zellij (session_serialization)
  -- restores the surrounding panes/tabs. Launched with no file args (e.g. when
  -- zellij relaunches an `nvim` pane) it auto-restores that dir's session;
  -- `nvim foo.py` skips restore. Manual control via <leader>q*.
  ----------------------------------------------------------------------------
  {
    "folke/persistence.nvim",
    lazy = false, -- load at startup so the auto-restore autocmd registers in time
    opts = {
      options = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "folds" },
    },
    config = function(_, opts)
      local persistence = require("persistence")
      persistence.setup(opts)
      vim.api.nvim_create_autocmd("VimEnter", {
        nested = true,
        callback = function()
          if vim.fn.argc() == 0 then persistence.load() end
        end,
      })
    end,
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "Restore session (this dir)" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore last session" },
      { "<leader>qd", function() require("persistence").stop() end, desc = "Stop saving this session" },
    },
  },
}
