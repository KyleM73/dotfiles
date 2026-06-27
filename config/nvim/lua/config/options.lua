-- Editor options — Lua equivalents of the useful bits from the old vimrc,
-- plus a few modern defaults. Lightly opinionated.
local opt = vim.opt

-- Line numbers: absolute on the cursor line, relative elsewhere (fast j/k jumps).
opt.number = true
opt.relativenumber = true

-- Indentation: 4-space, spaces-not-tabs (matches your vimrc and Python work).
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.smartindent = true
opt.autoindent = true

-- Search: case-insensitive unless the query has a capital; live highlight.
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- UI / behavior
opt.mouse = "a"          -- mouse on (handy in ghostty, even over SSH)
opt.signcolumn = "yes"   -- always show sign column (no jitter from gitsigns)
opt.cursorline = true    -- highlight the current line
opt.scrolloff = 8        -- keep context lines around the cursor
opt.termguicolors = true -- 24-bit color (ghostty supports it)
opt.wrap = false         -- no soft-wrap by default (toggle: <leader>tw)
opt.splitright = true    -- vertical splits open to the right
opt.splitbelow = true    -- horizontal splits open below
opt.title = true         -- set the terminal title to the file name
opt.undofile = true      -- persistent undo across sessions
opt.confirm = true       -- prompt to save instead of erroring on :q with changes
opt.updatetime = 250     -- snappier CursorHold (blame, diagnostics) than default 4s
opt.timeoutlen = 400     -- faster which-key popup (once enabled)

-- Render whitespace gremlins (tabs / trailing spaces), like VSCode's
-- "render whitespace" option. Helps catch mixed indentation.
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
