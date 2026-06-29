# dotfiles

Cross-platform shell, vim, screen, and git config that works interchangeably on
macOS and Linux, under both bash and zsh.

## Install

```sh
git clone https://github.com/KyleM73/dotfiles.git
cd dotfiles
./make_symlinks.sh
```

That single command is the whole setup. `make_symlinks.sh`:

- Backs up any existing real dotfiles to `~/dotfiles.bkp/` (re-running is safe; it
  won't clobber the symlinks it already made).
- Symlinks the repo files into `$HOME`, and the `config/` subdirs into
  `~/.config` (`$XDG_CONFIG_HOME`):

  | Repo path       | Symlink                    |
  | --------------- | -------------------------- |
  | `bashrc`        | `~/.bashrc` and `~/.zshrc` |
  | `aliases`       | `~/.aliases`               |
  | `vimrc`         | `~/.vimrc`                 |
  | `screenrc`      | `~/.screenrc`              |
  | `gitconfig`     | `~/.gitconfig`             |
  | `config/nvim`    | `~/.config/nvim`          |
  | `config/yazi`    | `~/.config/yazi`          |
  | `config/zellij`  | `~/.config/zellij`        |
  | `config/ghostty` | `~/.config/ghostty`       |

- Prompts for your git name/email (pre-filled from your existing `~/.gitconfig`)
  and writes them to `~/.gitconfig.local` — so identity is set automatically and
  never committed. Skipped if `~/.gitconfig.local` already exists.
- Offers to install the CLI tools the editor setup uses (Neovim, Zellij, Yazi,
  fzf, ripgrep, ruff, ty, …) via [`install_deps.sh`](#installing-the-tools).
  Skip with `SKIP_DEPS=1 ./make_symlinks.sh`.

`bashrc` is the single cross-shell init file, sourced by both bash and zsh.

## Machine-local overrides (secrets, work tools)

Nothing machine-specific or secret is committed. `bashrc` sources
`~/.bashrc.local` last if it exists — put per-host secrets, env vars, and
private aliases there:

```sh
# ~/.bashrc.local   (chmod 600; never tracked)
export SOME_API_KEY=...
alias work='...'
```

Git identity lives in `~/.gitconfig.local` (written for you by the setup
script, and included by `gitconfig`):

```ini
# ~/.gitconfig.local
[user]
    name = Your Name
    email = you@example.com
```

### Multiple git accounts (separate personal and work identities)

Identity switches automatically based on a repo's remote host — no per-repo
setup. The setup script can wire this up: it writes the work `[user]` block to
`~/.gitconfig-work` and appends conditional-include rules to `~/.gitconfig.local`
(both untracked, so no host or work details are committed). The rules look like:

```ini
# ~/.gitconfig.local (untracked) — replace example.com with your work host
[includeIf "hasconfig:remote.*.url:git@example.com:*/**"]
    path = ~/.gitconfig-work
[includeIf "hasconfig:remote.*.url:https://*example.com/**"]
    path = ~/.gitconfig-work
```

Two patterns are needed because git's URL glob treats `/` as a boundary, so a
single pattern can't match both `git@…` and `https://…` forms. Verify on any
repo with `git config user.email`.

**SSH keys:** when personal and work live on different hosts, route a separate
key per host in `~/.ssh/config` (works for clone, fetch, and push):

```
Host example.com
    IdentityFile ~/.ssh/id_work
    IdentitiesOnly yes
```

Generate keys with `ssh-keygen -t ed25519 -f ~/.ssh/id_work` and add the public
key to that host. (For two accounts on the *same* host, use a `Host` alias and
rewrite the remote to match it.)

## Conda

Conda is **lazy-loaded**: it is not initialized at startup and `base` is never
auto-activated. The first `conda` call initializes conda and runs your command,
so `conda activate <env>` just works on demand. Detection covers
anaconda/miniconda/miniforge/mambaforge, Homebrew Caskroom, and `/opt/conda`.

- `CONDA_HOME=/path` — point at a non-standard conda prefix.
- `NO_CONDA=1` — disable conda integration entirely for that shell.
- Recommended once per machine: `conda config --set auto_activate_base false`.

## Vim

Plugins are managed by [vim-plug](https://github.com/junegunn/vim-plug), which
auto-installs itself and the plugin set on first launch. Leader key is `Space`:

| Mapping       | Action            |
| ------------- | ----------------- |
| `<Space>n`    | Toggle NERDTree   |
| `<Space>m`    | Mirror NERDTree   |
| `<Space>o`    | Open session      |
| `<Space>t`    | New tab           |
| `<Space>e`    | Enable mouse      |
| `<Space>d`    | Disable mouse     |

The old Vim config is kept as-is; Neovim (below) is the primary editor. `$EDITOR`
prefers `nvim` and falls back to `vim` on machines without it.

## A VS Code-like terminal setup (Neovim + Zellij + Yazi)

Three tools combine into a lightweight, fully-in-terminal IDE that works the
same locally and over SSH (designed for Ghostty, but any modern terminal works):

- **Zellij** — the "window / workbench". One terminal window split into panes
  (editor + shell + file manager), and — crucially over SSH — it **survives
  disconnects**: detach and reattach later with your session intact.
- **Neovim** + **neo-tree** — the editor and its Explorer sidebar.
- **Yazi** — a standalone file manager in its own pane, for filesystem-heavy
  work (previews, bulk rename/move/delete) and `cd`-ing your shell around.

neo-tree and Yazi don't compete: neo-tree lives *inside* nvim for opening files
into buffers while you edit; Yazi is a separate full-screen file manager you pop
over to in another pane.

### Installing the tools

`make_symlinks.sh` runs `install_deps.sh` for you (skip with `SKIP_DEPS=1`), but
you can also run it standalone any time:

```sh
./install_deps.sh             # install everything that's missing
DRY_RUN=1 ./install_deps.sh   # show what it WOULD do, change nothing
```

It's **idempotent** (skips anything already on your `PATH`) and **best-effort**
(warns and continues on failure). Homebrew is **not required** — it detects the
package manager and does the right thing per platform:

- **macOS** → Homebrew.
- **Linux** → the native package manager (`apt`/`dnf`/`pacman`/`zypper`/`apk`,
  with `sudo` when needed) for `fzf`, `ripgrep`, a C compiler (for treesitter),
  and the optional preview tools.
- **Neovim, Zellij, and Yazi on Linux** are installed from their **official
  prebuilt releases into `~/.local/bin`** (no root, no compiler) — because
  apt's Neovim is too old for the Python LSP (needs ≥ 0.11) and Zellij/Yazi
  aren't packaged on Debian/Ubuntu. On Debian/Ubuntu it also symlinks `fdfind`
  → `fd` and `batcat` → `bat` so Yazi's previews find them.
- **`ruff` + `ty`** always go through **`uv`** (cross-platform, no root); `uv`
  itself is installed if missing.

`~/.local/bin` is added to your `PATH` by the shell config, so a freshly
installed Neovim wins over an older system one.

It also installs **Hack Nerd Font** (so neovim/yazi icons render) and the
Ghostty config sets it as the font. Note: over SSH the font only matters on the
machine running Ghostty (your Mac), not the remote box — there the Mac's Ghostty
draws the glyphs. Ghostty also falls back to bundled Nerd Font symbols
automatically, so icons work even before the font is installed.

One thing the script can't do for you:

- On macOS without a C compiler, run `xcode-select --install` (for treesitter).

## Neovim

A hand-written, modular config under `config/nvim/`, managed by
[lazy.nvim](https://github.com/folke/lazy.nvim) (auto-installs itself and all
plugins on first launch). Leader is `Space`.

**Philosophy: start minimal, grow one plugin at a time.** Every plugin lives in
its own file under `lua/plugins/`. The full VS Code-like set is already written;
features you haven't turned on yet carry `enabled = false`. To add one, open its
file, flip `enabled = false` → `true`, and restart nvim — lazy installs it. No
rewriting required.

| Plugin            | File                     | Role (VS Code analogue)             |
| ----------------- | ------------------------ | ----------------------------------- |
| neo-tree          | `plugins/filetree.lua`   | Explorer sidebar                    |
| yazi.nvim         | `plugins/filetree.lua`   | Floating yazi → open file in editor |
| gitsigns          | `plugins/git.lua`        | Source Control gutter (hunks/blame) |
| diffview          | `plugins/git.lua`        | Side-by-side diff + file history    |
| lazygit           | `plugins/git.lua`        | Full git UI (needs `lazygit` binary)|
| treesitter        | `plugins/treesitter.lua` | Syntax highlighting                 |
| fzf-lua           | `plugins/finder.lua`     | `Cmd-P` + project search            |
| LSP (ruff + ty)   | `plugins/lsp.lua`        | IntelliSense for Python             |
| blink.cmp         | `plugins/lsp.lua`        | Autocomplete popup                  |
| vscode.nvim       | `plugins/ui.lua`         | Theme (VS Code Dark Modern look)    |
| lualine           | `plugins/ui.lua`         | Status bar                          |
| indent-blankline  | `plugins/ui.lua`         | Indent guides                       |
| bufferline        | `plugins/ui.lua`         | Editor tabs                         |
| which-key         | `plugins/editor.lua`     | Keybinding hints popup              |
| autopairs         | `plugins/editor.lua`     | Auto-close brackets                 |
| vim-sleuth        | `plugins/editor.lua`     | Auto-detect indentation             |
| todo-comments     | `plugins/editor.lua`     | Highlight TODO/FIXME                 |
| trouble           | `plugins/editor.lua`     | Problems / diagnostics panel        |
| flash             | `plugins/editor.lua`     | Jump-to-anywhere motion (`s`)       |
| persistence       | `plugins/editor.lua`     | Session restore (per project)       |

Disabled by default (flip `enabled = true` to use): **tokyonight** (alternative
theme, `ui.lua`) and **mason** (LSP-server installer, `lsp.lua`).

Key mappings (leader = `Space`):

| Mapping                | Action                                   |
| ---------------------- | ---------------------------------------- |
| `<Space>?`             | Cheat-sheet overlay (a tab per tool)     |
| `<Space>e`             | Toggle file explorer (neo-tree)          |
| `<Space><Space>`       | Find files (fuzzy, like `Cmd-P`)         |
| `<Space>fg`            | Grep across the project                  |
| `<Space>fw`            | Grep word under cursor                   |
| `<Space>fb`            | Switch buffers                           |
| `gd` / `gr` / `K`      | Go to definition / references / hover    |
| `<Space>rn` / `<Space>ca` | Rename symbol / code action           |
| `<Space>cf`            | Format buffer                            |
| `]d` / `[d`            | Next / previous diagnostic               |
| `]c` / `[c`            | Next / previous git hunk                 |
| `<Space>hs` / `hr` / `hp` | Stage / reset / preview git hunk      |
| `<Space>hb` / `<Space>tb` | Blame line / toggle inline blame      |
| `<S-l>` / `<S-h>`      | Next / previous buffer (bufferline tab)  |
| `<C-h/j/k/l>`          | Move between splits                      |
| `s` / `S`              | Flash jump / treesitter jump             |
| `<Space>gg`            | LazyGit (full git UI)                    |
| `<Space>gd` / `gh` / `gq` | Diff view / file history / close      |
| `<Space>xx`            | Problems panel — all diagnostics (Trouble)|
| `]t` / `[t`            | Next / previous TODO comment             |
| `<Space>qs` / `<Space>ql` | Restore session (this dir / last)     |

**Python LSP uses the Astral stack** (`ruff` for lint/format, `ty` for types) —
all Rust, no Node/pyright. Install with `uv tool install ruff ty`; both
auto-detect the active venv / `pyproject.toml`. The config uses Neovim's native
`vim.lsp` API (0.11+); on older nvim the LSP file warns and skips itself.

**Clipboard over SSH:** yanks route through OSC52 when connected over SSH, so
`yy` on a remote box lands in your local clipboard. Locally the native
clipboard is used.

**Reproducible versions:** after the first launch, commit the generated
`config/nvim/lazy-lock.json` to pin exact plugin versions across machines
(`:Lazy restore` re-pins to it).

## Zellij

Terminal multiplexer / workspace, configured in `config/zellij/`. It wraps the
editor in VS Code-like chrome: an integrated terminal pane, project tabs, a
status bar, a theme matching the editor, and session persistence (survives SSH
disconnects — detach with `Ctrl o` then `d`, reattach with `zellij attach`).

- **Theme:** a `vscode-dark` palette (defined in `config.kdl`) matching the
  vscode.nvim editor. Change the `theme` line to swap it.
- **Layouts** (`config/zellij/layouts/`), each launchable via `zellij --layout NAME`:

  | Layout | Arrangement | Alias |
  | ------- | ------------------------------------------- | ----- |
  | default | nvim editor on top, terminal strip below (auto-opens nvim; used for every session) | `zj`  |
  | wide    | nvim editor left, terminal right            | `zjw` |
  | shell   | plain shell, no auto-nvim (quick one-offs)  | `zjs` |

  Open one in a new tab from a running session: `zellij action new-tab --layout wide`.
- **File manager:** browse with yazi *inside* nvim (`<Space>y`) — pick a file and
  it opens in the editor; close the float to hide it. (A yazi *zellij pane* can't
  hand a file to a running nvim without fragile RPC, so it's wired in-editor.)
- **Keys:** zellij defaults are kept (status bar shows the `Ctrl-` prefixes):
  `Ctrl p` panes, `Ctrl t` tabs, `Ctrl s` scrollback (Enter edits it in nvim),
  `Ctrl o` session, `Ctrl q` quit.
- Copy uses OSC52 (works over SSH); on a local Mac set `copy_command "pbcopy"`.

## Yazi

Terminal file manager, configured in `config/yazi/yazi.toml`. Launch it with
**`y`** (not plain `yazi`) — the shell wrapper makes your shell `cd` to wherever
you ended up when you quit. Files open in `$EDITOR` (nvim). Toggle hidden files
with `.`. Richer previews depend on the optional tools listed under
[Installing the tools](#installing-the-tools).

## Ghostty

Terminal config in `config/ghostty/config`. Sets the font to **Hack Nerd Font**
(installed by `install_deps.sh`) so neovim/yazi icons render; Ghostty also falls
back to bundled Nerd Font symbols automatically. Check what fonts Ghostty sees
with `ghostty +list-fonts | grep -i nerd`. The file has commented extras (theme,
opacity, padding) to tweak. Read on both macOS and Linux from
`~/.config/ghostty/config`.
