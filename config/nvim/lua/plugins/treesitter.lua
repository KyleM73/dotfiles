-- nvim-treesitter (main branch) — syntax-tree highlighting. The `main` branch is
-- the rewrite that supports Neovim 0.11+/0.12; the old `master` branch does NOT
-- support 0.12 (its indent module threw "attempt to call method 'range'" on
-- every keystroke). On `main`:
--   * highlighting is started per-buffer via vim.treesitter.start() (there is no
--     `highlight = {...}` option),
--   * there is no indent module, so indentation comes from Neovim's built-in
--     per-language indent + autoindent/smartindent (options.lua) + vim-sleuth,
--   * parsers are built with the `tree-sitter` CLI (install_deps.sh installs it)
--     plus a C compiler, and persist on disk across sessions.
-- Add more languages with :TSInstall <lang> (or extend the install list below).
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    -- Install/keep these parsers (async; builds via the tree-sitter CLI, persists).
    require("nvim-treesitter").install({
      "lua", "python", "bash", "json", "yaml", "toml",
      "markdown", "markdown_inline", "gitcommit", "diff", "vim", "vimdoc",
    })
    -- Start highlighting for any buffer whose filetype has an installed parser.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        pcall(vim.treesitter.start, ev.buf)
      end,
    })
  end,
}
