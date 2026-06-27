-- git: gitsigns (in-buffer hunks/blame) + diffview (full diff & history views).
-- Together these are the in-editor equivalent of VS Code's Source Control.
return {
  ----------------------------------------------------------------------------
  -- gitsigns.nvim — per-line git in the gutter + hunk staging / preview / blame.
  ----------------------------------------------------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local function map(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
        end

        -- Jump between changed hunks.
        map("n", "]c", function() gs.nav_hunk("next") end, "Next git hunk")
        map("n", "[c", function() gs.nav_hunk("prev") end, "Prev git hunk")

        -- Act on the hunk under the cursor.
        -- (stage_hunk toggles: run it again on a staged hunk to unstage.)
        map("n", "<leader>hs", gs.stage_hunk, "Stage/unstage hunk")
        map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
        map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")

        -- Blame + diff.
        map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
        map("n", "<leader>tb", gs.toggle_current_line_blame, "Toggle inline blame")
        map("n", "<leader>hd", gs.diffthis, "Diff this file")
      end,
    },
  },

  ----------------------------------------------------------------------------
  -- diffview.nvim — VS Code-style side-by-side diff viewer + git file/branch
  -- history. Navigate changed files in a sidebar, view diffs, browse history.
  -- Close any diffview tab with <leader>gq (or :DiffviewClose / `q`).
  ----------------------------------------------------------------------------
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Git diff (working tree)" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "Git history (this file)" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diff view" },
    },
    opts = {},
  },

  ----------------------------------------------------------------------------
  -- lazygit.nvim — open the lazygit TUI in a floating window: a full git client
  -- (stage, commit, branch, rebase, push/pull, interactive log). Requires the
  -- `lazygit` binary, which install_deps.sh installs.
  ----------------------------------------------------------------------------
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "LazyGit", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    keys = {
      { "<leader>gg", "<cmd>LazyGit<CR>", desc = "LazyGit (full git UI)" },
    },
  },
}
