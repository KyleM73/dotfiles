-- nvim-treesitter — syntax-tree-based highlighting + indentation (far better
-- than regex highlighting), and code-aware text objects/motions. ACTIVE.
--
-- Parsers are COMPILED on install, so a C compiler must be on PATH:
--   macOS: xcode-select --install
--   Linux: install gcc (or clang) + make via your package manager
-- (Pinned to the stable `master` branch + classic setup API.)
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  main = "nvim-treesitter.configs",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    ensure_installed = {
      "lua", "python", "bash", "json", "yaml", "toml",
      "markdown", "markdown_inline", "gitcommit", "diff", "vim", "vimdoc",
      -- Add more as you need them: "cpp", "rust", "typescript", "tsx", "cmake" ...
    },
    auto_install = true, -- auto-install a parser when you open a new filetype
    highlight = { enable = true },
    indent = { enable = true },
  },
}
