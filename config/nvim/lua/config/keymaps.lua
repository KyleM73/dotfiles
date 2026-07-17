-- Keymaps and commands that don't belong to a specific plugin. (Plugin keymaps
-- live next to their plugin in lua/plugins/.) Leader is <Space>.
local map = vim.keymap.set

-- Clear search highlight on <Esc>.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Toggle soft-wrap (off by default; handy for prose / markdown).
map("n", "<leader>tw", "<cmd>set wrap!<CR>", { desc = "[T]oggle [w]rap" })

-- Floating cheat-sheet overlay (a tab per tool). See lua/config/cheatsheet.lua.
map("n", "<leader>?", function() require("config.cheatsheet").open() end, { desc = "Cheat sheet overlay" })

-- Move between splits/windows with Ctrl + h/j/k/l.
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Cycle buffers (VSCode-like tab switching).
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })

-- Keep the cursor centered on half-page scroll and search jumps.
map("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (centered)" })
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Move the visual selection up/down (like Alt+Up/Down in VSCode).
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode after shifting indentation.
map("v", "<", "<gv")
map("v", ">", ">gv")

-- :Ea[!] ("edit all") — like :e, but for every open file buffer (e.g. after a git
-- pull). Modified buffers are skipped and counted; ! discards their changes.
-- Special buffers (terminals, neo-tree, ...) are left alone.
vim.api.nvim_create_user_command("Ea", function(opts)
  local ok, skipped, failed = 0, 0, 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted
      and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= "" then
      if vim.bo[buf].modified and not opts.bang then
        skipped = skipped + 1
      elseif pcall(vim.api.nvim_buf_call, buf, function() vim.cmd(opts.bang and "edit!" or "edit") end) then
        ok = ok + 1
      else
        failed = failed + 1
      end
    end
  end
  local msg = ("Reloaded %d buffer%s"):format(ok, ok == 1 and "" or "s")
  if skipped > 0 then msg = msg .. (", %d skipped (unsaved — :Ea! to force)"):format(skipped) end
  if failed > 0 then msg = msg .. (", %d failed"):format(failed) end
  vim.notify(msg, (skipped + failed > 0) and vim.log.levels.WARN or vim.log.levels.INFO)
end, { bang = true, desc = "Reload all open file buffers from disk (! discards unsaved changes)" })
