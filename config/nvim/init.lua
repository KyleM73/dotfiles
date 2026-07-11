-- ~/.config/nvim/init.lua
-- Neovim config — hand-written and modular: one file per concern under
-- lua/plugins/, all imported by lazy.nvim below.
--
-- The full VS Code-like set is ENABLED. To turn any feature off, open its file
-- and set `enabled = false` on the spec — it is then skipped entirely (not
-- installed, no keymaps). Two specs ship disabled as easy swaps: tokyonight
-- (alternative theme, ui.lua) and mason (LSP-server installer, lsp.lua).
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
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    -- Without this check a failed clone (no network/proxy) surfaces later as a
    -- cryptic "module 'lazy' not found" instead of the actual git error.
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit...", "MoreMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Import every spec file in lua/plugins/. Specs with `enabled = false` are
-- skipped entirely (not installed, no keymaps).
require("lazy").setup({
  spec = { { import = "plugins" } },
  change_detection = { notify = false }, -- don't nag when these files change
  ui = { border = "rounded" },
})
