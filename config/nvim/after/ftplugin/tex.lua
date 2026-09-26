-- Soft wrap for LaTeX: long lines stay one line in the file but display
-- folded at the window edge, like a word processor. textwidth = 0 keeps
-- nvim from inserting hard newlines while typing.
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true
vim.opt_local.textwidth = 0

-- Move by displayed line rather than file line so j/k/0/$ follow what is
-- on screen instead of jumping a whole paragraph at a time.
for _, m in ipairs({ { "j", "gj" }, { "k", "gk" }, { "0", "g0" }, { "$", "g$" } }) do
  vim.keymap.set({ "n", "v" }, m[1], m[2], { buffer = true })
end
