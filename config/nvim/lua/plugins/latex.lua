-- LaTeX: vimtex runs latexmk in continuous-compile mode and drives a SyncTeX
-- viewer (Skim on macOS; installed and configured by install_deps.sh).
-- Respects a per-project .latexmkrc (e.g. $out_dir = 'build').
-- Shared-config repos: if a file named `latexmkrc` (no dot) sits in an
-- ancestor dir of the document (e.g. ~/projects/papers), latexmk is run with
-- `-r <that file>` so every paper in the repo builds the same way without a
-- per-paper rc file (Overleaf-synced dirs can't carry one).
-- <Space>ll compile-on-save · <Space>lv forward search · <Space>le errors.
-- Don't :TSInstall latex — treesitter highlighting fights vimtex's.

-- Nearest ancestor `latexmkrc` above the current buffer's dir, or nil.
local function shared_latexmkrc()
  local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  if not dir or dir == "" then
    return nil
  end
  return vim.fs.find("latexmkrc", { upward = true, path = dir, type = "file" })[1]
end

return {
  "lervag/vimtex",
  version = "*", -- releases support nvim 0.10+; master can require a days-old nvim
  lazy = false,  -- vimtex lazy-loads itself; manager-level lazy breaks inverse search
  init = function()
    -- vimtex reads its g: options at load time, hence init (not config).
    if vim.fn.has("mac") == 1 then
      vim.g.vimtex_view_method = "skim"
      vim.g.vimtex_view_skim_sync = 1     -- forward search after each compile
      -- Keep focus in nvim: with sync on, activate=1 raises Skim on every
      -- save. Skim still scrolls to the cursor line beside the editor.
      vim.g.vimtex_view_skim_activate = 0
    end
    vim.g.vimtex_quickfix_open_on_warning = 0 -- auto-open quickfix on errors only

    -- Per document, before vimtex builds its compiler: PDF + aux in build/,
    -- SyncTeX on, and the repo's shared latexmkrc if there is one. vimtex
    -- reads g:vimtex_compiler_latexmk when it initializes each document.
    vim.api.nvim_create_autocmd("User", {
      pattern = "VimtexEventInitPre",
      callback = function()
        local opts = {
          out_dir = "build",
          aux_dir = "build",
          callback = 1,
          continuous = 1,
          executable = "latexmk",
          options = { "-verbose", "-file-line-error", "-synctex=1", "-interaction=nonstopmode" },
        }
        local rc = shared_latexmkrc()
        if rc then
          table.insert(opts.options, 1, rc)
          table.insert(opts.options, 1, "-r")
        end
        vim.g.vimtex_compiler_latexmk = opts
      end,
    })

    -- Start latexmk continuous compile as soon as vimtex initializes a tex
    -- buffer, so compile-on-save + Skim reload work without pressing
    -- <Space>ll each session. The bang form is a no-op when the project's
    -- compiler is already running (opening a second file of the same
    -- document will not toggle it off).
    vim.api.nvim_create_autocmd("User", {
      pattern = "VimtexEventInitPost",
      command = "VimtexCompile!",
    })
  end,
}
