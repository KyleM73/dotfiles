-- gitsigns.nvim — per-line git in the gutter + hunk staging / preview / blame.
-- ACTIVE. This is the in-editor half of VSCode's Source Control panel: it shows
-- which LINES changed and lets you stage / reset / preview them.
return {
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
}
