-- ~/.config/nvim/init.lua
-- Neovim config — hand-written, modular, and designed to GROW.
--
-- Philosophy: start MINIMAL, enable features one at a time.
--   * Active now:  neo-tree (file sidebar) + gitsigns (git gutter).
--   * Everything else needed for a VSCode-like experience is already written
--     under lua/plugins/ but DISABLED via `enabled = false`. To turn a feature
--     on, open its file, flip `enabled = false` -> `true`, and restart nvim.
--     lazy.nvim installs it on next launch. Nothing to rewrite.
--
-- Suggested enable order (each is independent; this just sequences nicely):
--   1. lua/plugins/ui.lua      colorscheme + treesitter + statusline   (looks/highlighting)
--   2. lua/plugins/finder.lua  fzf-lua: Cmd-P file open + project grep  (needs fzf + ripgrep)
--   3. lua/plugins/editor.lua  which-key (keybind hints) + autopairs
--   4. lua/plugins/lsp.lua     LSP (ruff + ty for Python) + blink.cmp   => full IDE
--
-- Layout:
--   init.lua                 this file: leader, bootstrap, load order
--   lua/config/options.lua   editor options (numbers, indent, search, ...)
--   lua/config/keymaps.lua   keymaps that aren't tied to a plugin
--   lua/config/clipboard.lua OSC52 clipboard (yank over SSH -> local clipboard)
--   lua/plugins/*.lua        one file per concern; lazy.nvim imports them all

-- Leader MUST be set before lazy / plugins load.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Is a Nerd Font active in the terminal? neo-tree / statusline icons need one.
-- Set to false if you see boxes or "?" instead of file-type icons.
vim.g.have_nerd_font = true

-- Core editor settings & keymaps (no plugins involved).
require("config.options")
require("config.keymaps")
require("config.clipboard")

-- Bootstrap lazy.nvim (the plugin manager) on first launch.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Import every spec file in lua/plugins/. Specs with `enabled = false` are
-- skipped entirely (not installed, no keymaps), so the minimal start is just
-- whatever is enabled.
require("lazy").setup({
  spec = { { import = "plugins" } },
  change_detection = { notify = false }, -- don't nag when these files change
  ui = { border = "rounded" },
})
