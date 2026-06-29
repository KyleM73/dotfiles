-- A floating "cheat sheet" overlay with a tab per tool — a learning aid for the
-- keybinds in this setup. Open with <leader>?  ·  switch tabs with Tab / S-Tab
-- (or h / l, or 1-9)  ·  close with q or <Esc>.
--
-- This is just a static reference. For LIVE nvim hints, which-key already pops
-- up every <leader> mapping when you press <Space> and pause.
local M = {}

-- Each section is one tab. Keep keybinds here in sync with the configs.
M.sections = {
  { name = "Neovim", lines = {
    "Leader = <Space>   (which-key pops these up as you type)",
    "",
    "<C-h/j/k/l>      move between splits",
    "<S-l> / <S-h>    next / prev buffer",
    "<C-d> / <C-u>    half-page down / up (centered)",
    "J / K (visual)   move selection down / up",
    "< / > (visual)   dedent / indent",
    "<Esc>            clear search highlight",
    "<leader>tw       toggle line wrap",
    ":w  :q  :qa      save / close window / quit all",
    ":bd              close (delete) the current buffer",
  }},
  { name = "Find", lines = {
    "<leader><leader>  find files (like Cmd-P)",
    "<leader>ff        find files",
    "<leader>fg        grep across the project",
    "<leader>fw        grep word under cursor",
    "<leader>fb        open buffers",
    "<leader>fs        document symbols",
    "<leader>fd        diagnostics",
    "<leader>fh        help tags",
    "<leader>fr        resume last search",
    "<leader>ft        list TODOs",
  }},
  { name = "Code", lines = {
    "gd / gr / gi     go to definition / references / implementation",
    "gD               go to declaration",
    "K                hover docs",
    "<leader>rn       rename symbol",
    "<leader>ca       code action",
    "<leader>cf       format buffer",
    "<leader>cd       line diagnostics (float)",
    "]d / [d          next / prev diagnostic",
  }},
  { name = "Complete", lines = {
    "Tab              accept the suggestion",
    "Up/Down or C-n/C-p   move the selection",
    "<C-space>        open / toggle the menu",
    "<C-e>            hide the menu",
    "Enter            normal newline (does NOT accept)",
  }},
  { name = "Git", lines = {
    "<leader>gg       lazygit (full git UI)",
    "<leader>gd       diff view (working tree)",
    "<leader>gh       file history (current file)",
    "<leader>gq       close diff view",
    "]c / [c          next / prev changed hunk",
    "<leader>hs/hr/hp stage / reset / preview hunk",
    "<leader>hb       blame line    <leader>tb  toggle inline blame",
    "<leader>hd       diff this file",
  }},
  { name = "Diag", lines = {
    "<leader>xx       Problems: all diagnostics (Trouble)",
    "<leader>xX       diagnostics: current buffer",
    "<leader>xs       symbols outline",
    "<leader>xq / xl  quickfix / location list",
    "<leader>xt       TODOs",
  }},
  { name = "Motion", lines = {
    "s then chars     flash jump (then press the shown label)",
    "S                flash by treesitter node",
    "]t / [t          next / prev TODO comment",
  }},
  { name = "Files", lines = {
    "<leader>e        toggle file explorer (neo-tree)",
    "<leader>o        focus the explorer",
    "<leader>y        open yazi here (Enter opens it in editor)",
    "<leader>Y        open yazi at cwd",
    "<leader>yr       resume last yazi",
  }},
  { name = "Session", lines = {
    "<leader>qs       restore this directory's session",
    "<leader>ql       restore the last session",
    "<leader>qd       stop saving this session",
    "(auto-restores when you open `nvim` with no file arguments)",
  }},
  { name = "Zellij", lines = {
    "Alt+h/j/k/l      move between panes (editor <-> terminal)",
    "Ctrl+t  then...  1-9 / arrows switch tabs, n new tab, x close",
    "Ctrl+p  then...  n new pane, x close, d / r split down / right",
    "Ctrl+n           resize mode      Alt+= / Alt+-  resize",
    "Ctrl+s           scrollback (then e: edit it in nvim)",
    "Ctrl+o then d    detach     ($ zellij attach  to reattach)",
    "Ctrl+q           quit the session",
    "$ zj / zjw / zjs default / wide / plain-shell layout",
  }},
  { name = "Yazi", lines = {
    "h/j/k/l          navigate       Enter  open",
    ".                toggle hidden  ~ or F1  in-app help",
    "y / x / p        yank / cut / paste",
    "d / a / r        delete / create / rename",
    "q                quit (your shell cd's to where you ended up)",
  }},
}

M.current = 1
local state = { buf = nil, win = nil, width = 84 }

local function render()
  -- Tab bar across two rows so all tabs fit a narrow column.
  local total = #M.sections
  local half = math.ceil(total / 2)
  local row1, row2 = {}, {}
  for i, s in ipairs(M.sections) do
    local label = (i == M.current) and ("[" .. s.name .. "]") or (" " .. s.name .. " ")
    if i <= half then
      row1[#row1 + 1] = label
    else
      row2[#row2 + 1] = label
    end
  end
  local lines = {
    table.concat(row1, " "),
    table.concat(row2, " "),
    string.rep("─", state.width),
    "",
  }
  for _, l in ipairs(M.sections[M.current].lines) do
    lines[#lines + 1] = "  " .. l
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Tab/h/l: switch · 1-9: jump · q/Esc: close"
  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function switch(n, absolute)
  local total = #M.sections
  if absolute then
    if n >= 1 and n <= total then M.current = n end
  else
    M.current = ((M.current - 1 + n) % total) + 1
  end
  render()
end

function M.open()
  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  -- Top-right corner. Width tracks the longest line (so nothing wraps) but stays
  -- between 1/3 and 1/2 of the screen; height fits the tallest tab, capped at
  -- half the screen (the hints are short, so it never needs full height).
  local maxlen, maxrows = 0, 0
  for _, s in ipairs(M.sections) do
    maxrows = math.max(maxrows, #s.lines)
    for _, l in ipairs(s.lines) do
      maxlen = math.max(maxlen, #l)
    end
  end
  local lo, hi = math.floor(vim.o.columns / 3), math.floor(vim.o.columns / 2)
  local width = math.max(lo, math.min(maxlen + 4, hi)) -- +4: 2-space indent + pad
  local height = math.min(math.floor(vim.o.lines / 2), maxrows + 6) -- +6: tab rows + chrome
  state.width = width
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 1,
    col = vim.o.columns - width - 2,
    style = "minimal",
    border = "rounded",
    title = " Cheat sheet ",
    title_pos = "center",
  })
  vim.wo[state.win].wrap = true
  render()
  local function close()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
  end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true })
  end
  map("q", close)
  map("<Esc>", close)
  map("<Tab>", function() switch(1) end)
  map("l", function() switch(1) end)
  map("<S-Tab>", function() switch(-1) end)
  map("h", function() switch(-1) end)
  for i = 1, math.min(9, #M.sections) do
    map(tostring(i), function() switch(i, true) end)
  end
end

return M
