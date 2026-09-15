-- LaTeX: vimtex runs latexmk in continuous-compile mode and drives a SyncTeX
-- viewer (Skim on macOS; installed and configured by install_deps.sh).
-- Respects a per-project .latexmkrc (e.g. $out_dir = 'build').
-- <Space>ll compile-on-save · <Space>lv forward search · <Space>le errors.
-- Don't :TSInstall latex — treesitter highlighting fights vimtex's.
return {
  "lervag/vimtex",
  version = "*", -- releases support nvim 0.10+; master can require a days-old nvim
  lazy = false,  -- vimtex lazy-loads itself; manager-level lazy breaks inverse search
  init = function()
    -- vimtex reads its g: options at load time, hence init (not config).
    if vim.fn.has("mac") == 1 then
      vim.g.vimtex_view_method = "skim"
      vim.g.vimtex_view_skim_sync = 1     -- forward search after each compile
      vim.g.vimtex_view_skim_activate = 1 -- focus Skim on view
    end
    vim.g.vimtex_quickfix_open_on_warning = 0 -- auto-open quickfix on errors only
  end,
}
