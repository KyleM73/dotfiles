-- LSP (IntelliSense) + autocomplete — the core of the "IDE" experience:
-- go-to-definition, hover docs, diagnostics, rename, references, completion.
-- ACTIVE.
--
-- Python toolchain (Astral — all Rust, very fast, no Node/pyright):
--   ruff -> linting + formatting + import-sorting + code actions
--   ty   -> type checking + hover/types  (Astral's type checker; new)
-- Install both with uv (matches your uv/conda workflow); they auto-detect the
-- active venv / pyproject.toml:
--   uv tool install ruff
--   uv tool install ty
--
-- Uses Neovim's NATIVE LSP API (vim.lsp.config / vim.lsp.enable, 0.11+) rather
-- than nvim-lspconfig's deprecated .setup() framework. nvim-lspconfig is still
-- listed below only because it ships ready-made server definitions that
-- `vim.lsp.enable("lua_ls")` etc. can pick up for other languages.
return {
  ----------------------------------------------------------------------------
  -- LSP configuration (native API).
  ----------------------------------------------------------------------------
  {
    "neovim/nvim-lspconfig", -- provides bundled server configs for vim.lsp.enable
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      -- The native API needs Neovim 0.11+. On older remote boxes, warn and bail
      -- rather than erroring (disable this file there, or update nvim).
      if not vim.lsp.config or not vim.lsp.enable then
        vim.notify(
          "lua/plugins/lsp.lua needs Neovim 0.11+ (vim.lsp.config). "
            .. "Update nvim or set enabled=false on this spec.",
          vim.log.levels.WARN
        )
        return
      end

      -- Advertise blink.cmp's completion capabilities to every server.
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Python: ruff (lint/format) + ty (types). Defined explicitly so they
      -- don't depend on nvim-lspconfig bundling a config for the brand-new ty.
      vim.lsp.config("ruff", {
        cmd = { "ruff", "server" },
        filetypes = { "python" },
        root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
      })
      vim.lsp.config("ty", {
        cmd = { "ty", "server" },
        filetypes = { "python" },
        root_markers = { "ty.toml", "pyproject.toml", "setup.py", "setup.cfg", ".git" },
      })
      vim.lsp.enable({ "ruff", "ty" })

      -- More languages: install the server on PATH and add it to the enable
      -- list. nvim-lspconfig ships the configs, so usually no vim.lsp.config
      -- block is needed:  vim.lsp.enable({ "lua_ls", "clangd", "rust_analyzer" })

      -- Buffer-local keymaps, applied when a server attaches.
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(ev)
          local client = vim.lsp.get_client_by_id(ev.data.client_id)
          -- ruff and ty complement each other: let ty own hover/types and
          -- silence ruff's hover so you don't get duplicate popups.
          if client and client.name == "ruff" then
            client.server_capabilities.hoverProvider = false
          end

          local function map(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "References")
          map("gi", vim.lsp.buf.implementation, "Go to implementation")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")
          map("K", vim.lsp.buf.hover, "Hover docs")
          map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>cf", function() vim.lsp.buf.format({ async = true }) end, "Format buffer")
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          map("]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
          map("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev diagnostic")
        end,
      })

      -- Diagnostics display (inline virtual text + signs + rounded floats).
      vim.diagnostic.config({
        virtual_text = true,
        severity_sort = true,
        float = { border = "rounded" },
      })
    end,
  },

  ----------------------------------------------------------------------------
  -- blink.cmp — fast completion engine (Rust fuzzy matcher), simpler to set up
  -- than nvim-cmp. `version = "*"` pulls a release with a prebuilt binary, so
  -- you do NOT need a Rust toolchain. Provides the popup + LSP capabilities.
  -- Default keys: <C-space> open, <C-y> accept, <C-n>/<C-p> or arrows to move,
  -- <Tab>/<S-Tab> jump snippet placeholders.
  ----------------------------------------------------------------------------
  {
    "saghen/blink.cmp",
    version = "*",
    event = "InsertEnter",
    opts = {
      -- Tab accepts the suggestion. Enter is intentionally left unbound so it
      -- stays a normal newline (won't accept). Arrows or C-n/C-p move the
      -- selection, C-space toggles the menu, C-e hides it. (blink's "default"
      -- preset only accepts with C-y, which is why Tab seemed to do nothing.)
      keymap = {
        preset = "none",
        ["<Tab>"]     = { "select_and_accept", "snippet_forward", "fallback" },
        ["<S-Tab>"]   = { "snippet_backward", "fallback" },
        ["<Down>"]    = { "select_next", "fallback" },
        ["<Up>"]      = { "select_prev", "fallback" },
        ["<C-n>"]     = { "select_next", "fallback" },
        ["<C-p>"]     = { "select_prev", "fallback" },
        ["<C-space>"] = { "show", "hide" },
        ["<C-e>"]     = { "hide", "fallback" },
      },
      appearance = { nerd_font_variant = "mono" },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
      signature = { enabled = true },
    },
  },

  ----------------------------------------------------------------------------
  -- OPTIONAL: mason.nvim — cross-platform installer for LSP servers / tools.
  -- Handy for lua_ls / clangd / rust-analyzer. Python's ruff + ty are better
  -- installed via uv, so mason is optional. Flip enabled = true to use it.
  ----------------------------------------------------------------------------
  {
    "williamboman/mason.nvim",
    enabled = false,
    cmd = "Mason",
    opts = {},
  },
}
