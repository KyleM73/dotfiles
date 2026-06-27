-- Fuzzy finder — VSCode's Cmd-P (open file) and project-wide search (Cmd-Shift-F).
-- ACTIVE. fzf-lua is the lightest/fastest option: it wraps the `fzf` binary and
-- uses `ripgrep` for live grep. (Telescope is a pure-Lua alternative if you'd
-- rather avoid external binaries — swap it in here if you prefer.)
--
-- Requires the `fzf` and `ripgrep` (rg) binaries on PATH:
--   macOS: brew install fzf ripgrep
--   Linux: apt install fzf ripgrep   (or your distro's equivalent)
return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  cmd = "FzfLua",
  keys = {
    { "<leader><leader>", "<cmd>FzfLua files<CR>", desc = "Find files (Cmd-P)" },
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "[F]ind [f]iles" },
    { "<leader>fg", "<cmd>FzfLua live_grep<CR>", desc = "[F]ind by [g]rep (project)" },
    { "<leader>fw", "<cmd>FzfLua grep_cword<CR>", desc = "[F]ind [w]ord under cursor" },
    { "<leader>fb", "<cmd>FzfLua buffers<CR>", desc = "[F]ind open [b]uffers" },
    { "<leader>fh", "<cmd>FzfLua helptags<CR>", desc = "[F]ind [h]elp" },
    { "<leader>fd", "<cmd>FzfLua diagnostics_document<CR>", desc = "[F]ind [d]iagnostics" },
    { "<leader>fr", "<cmd>FzfLua resume<CR>", desc = "[F]ind: [r]esume last" },
    -- LSP-powered pickers (no-ops until lsp.lua attaches a server):
    { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<CR>", desc = "[F]ind [s]ymbols (file)" },
  },
  opts = {
    winopts = { height = 0.85, width = 0.85, preview = { default = "bat" } },
  },
}
