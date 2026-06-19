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
- Symlinks the repo files into `$HOME`:

  | Repo file   | Symlink                    |
  | ----------- | -------------------------- |
  | `bashrc`    | `~/.bashrc` and `~/.zshrc` |
  | `aliases`   | `~/.aliases`               |
  | `vimrc`     | `~/.vimrc`                 |
  | `screenrc`  | `~/.screenrc`              |
  | `gitconfig` | `~/.gitconfig`             |

- Prompts for your git name/email (pre-filled from your existing `~/.gitconfig`)
  and writes them to `~/.gitconfig.local` — so identity is set automatically and
  never committed. Skipped if `~/.gitconfig.local` already exists.

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
