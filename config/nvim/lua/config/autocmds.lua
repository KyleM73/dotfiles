-- Publish "dir/filename" as the terminal title so zellij's tab bar can name the
-- tab after the file you're editing (see config/zellij/ztab.sh). `set title` is
-- already on (options.lua); here we point titlestring at dir/filename. Setting
-- the title is free — nvim just emits an escape sequence, no external process —
-- so it can track every buffer/dir change. The only external call is a single
-- tab rename when nvim opens; after that the `ztab` refresh (shell) and the
-- <leader>tz map read the title we keep current here.
local function tab_name()
  local file = vim.fn.expand("%:t")
  if file == "" then
    return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  end
  local dir = vim.fn.expand("%:p:h:t")
  return (dir ~= "" and dir .. "/" or "") .. file
end

local grp = vim.api.nvim_create_augroup("ZellijTabTitle", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufWritePost", "DirChanged" }, {
  group = grp,
  callback = function()
    vim.o.titlestring = tab_name()
  end,
})

-- Fire-once: name this tab as soon as nvim opens inside a zellij pane.
vim.api.nvim_create_autocmd("VimEnter", {
  group = grp,
  callback = function()
    vim.o.titlestring = tab_name()
    if vim.env.ZELLIJ then
      vim.system({ vim.fn.expand("~/.config/zellij/ztab.sh"), "set", tab_name() })
    end
  end,
})
