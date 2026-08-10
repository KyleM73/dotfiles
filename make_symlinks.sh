#!/usr/bin/env bash
# Symlinks the dotfiles into $HOME and sets up local git identity.
# Run from the repo: ./make_symlinks.sh   (or: source make_symlinks.sh to reload now)
# NOTE: loop lists are spelled out literally (not $var expansions) so the script
# also works sourced from zsh, which doesn't word-split unquoted variables.

# Resolve this script's directory in both Zsh and Bash
if [ -n "$ZSH_VERSION" ]; then
    DOTFILES="$(cd "$(dirname "${(%):-%N}")" && pwd)"
    SYMLINK_BASENAME="zshrc"
else
    DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    SYMLINK_BASENAME="bashrc"
fi

DOTFILES_BKP=~/dotfiles.bkp

# Capture existing git identity before ~/.gitconfig is replaced
EXISTING_NAME="$(git config --global user.name 2>/dev/null)"
EXISTING_EMAIL="$(git config --global user.email 2>/dev/null)"

mkdir -p "$DOTFILES_BKP"

# Move a real (non-symlink) file/dir out of the way without clobbering or
# nesting into an earlier backup of the same name.
backup() {  # backup <path>
    local bkp="$DOTFILES_BKP/$(basename "$1")"
    [ -e "$bkp" ] && bkp="$bkp.$(date +%Y%m%d%H%M%S).$$"
    mv "$1" "$bkp"
}

# Back up real files (not our own symlinks), then link
echo "Linking dotfiles into $HOME (backups in $DOTFILES_BKP)"
for file in aliases vimrc screenrc gitconfig zshenv; do
    [ -e ~/."$file" ] && [ ! -L ~/."$file" ] && backup ~/."$file"
    ln -sf "$DOTFILES/$file" ~/."$file"
    echo "  ~/.$file -> $DOTFILES/$file"
done

# Both shells share the same rc file
for rc in bashrc zshrc; do
    [ -e ~/."$rc" ] && [ ! -L ~/."$rc" ] && backup ~/."$rc"
    ln -sf "$DOTFILES/bashrc" ~/."$rc"
    echo "  ~/.$rc -> $DOTFILES/bashrc"
done

# XDG config directories -> ~/.config/<name>
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "$XDG_CONFIG"
echo "Linking config dirs into $XDG_CONFIG"
for dir in nvim yazi zellij ghostty; do
    target="$XDG_CONFIG/$dir"
    # Back up a real (non-symlink) existing dir, then link. -n stops ln from
    # nesting the link inside an existing symlinked dir on re-run.
    [ -e "$target" ] && [ ! -L "$target" ] && backup "$target"
    ln -sfn "$DOTFILES/config/$dir" "$target"
    echo "  $target -> $DOTFILES/config/$dir"
done

# Pre-authorize the zjstatus tab-bar plugin. Zellij has plugins request
# permissions via an interactive prompt, but our 1-line bar pane has no room to
# show it — so grant it up front by seeding zellij's permission cache (the
# documented mechanism; see config/zellij/config.kdl). Idempotent; per-OS cache.
ZJURL="$(grep -oE 'https://[^"]*zjstatus\.wasm' "$DOTFILES/config/zellij/config.kdl" 2>/dev/null | head -1)"
if [ -n "$ZJURL" ]; then
    case "$(uname -s)" in
        Darwin) ZJCACHE="$HOME/Library/Caches/org.Zellij-Contributors.Zellij" ;;
        *)      ZJCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zellij" ;;
    esac
    ZJPERM="$ZJCACHE/permissions.kdl"
    if [ -f "$ZJPERM" ] && grep -qF "$ZJURL" "$ZJPERM"; then
        echo "  zjstatus tab-bar plugin already authorized"
    else
        mkdir -p "$ZJCACHE"
        printf '"%s" {\n    ReadApplicationState\n    ChangeApplicationState\n    RunCommands\n}\n' \
            "$ZJURL" >> "$ZJPERM"
        echo "  authorized zjstatus tab-bar plugin -> $ZJPERM"
    fi
fi

# Local git identity (untracked; never committed)
GITLOCAL="$HOME/.gitconfig.local"
if [ ! -f "$GITLOCAL" ]; then
    if [ -t 0 ]; then
        echo
        echo "Setting up personal git identity in $GITLOCAL"
        # Loop until non-empty: an empty ident makes every `git commit` fail,
        # and this block never re-runs once $GITLOCAL exists.
        name=""; email=""
        while [ -z "$name" ]; do
            printf "  Full name%s: " "${EXISTING_NAME:+ [$EXISTING_NAME]}"; read -r name
            name="${name:-$EXISTING_NAME}"
        done
        while [ -z "$email" ]; do
            printf "  Email%s: " "${EXISTING_EMAIL:+ [$EXISTING_EMAIL]}"; read -r email
            email="${email:-$EXISTING_EMAIL}"
        done
        printf '[user]\n\tname = %s\n\temail = %s\n' "$name" "$email" > "$GITLOCAL"
        echo "  wrote $GITLOCAL"

        # Optional work identity, auto-selected by remote host (kept untracked)
        printf "\nSet up a separate work git identity for a specific host? [y/N]: "; read -r ans
        case "$ans" in
            [Yy]*)
                printf "  Work git host (e.g. github.com, gitlab.com, company domain): "; read -r whost
                printf "  Work name [%s]: " "$name"; read -r wname
                printf "  Work email: "; read -r wemail
                if [ -z "$whost" ] || [ -z "$wemail" ]; then
                    # An empty host would glob-match EVERY https remote.
                    echo "  ! host and email are both required — skipped."
                    echo "    (to redo identity setup: rm $GITLOCAL and re-run)"
                else
                    printf '[user]\n\tname = %s\n\temail = %s\n' \
                        "${wname:-$name}" "$wemail" > "$HOME/.gitconfig-work"
                    # Route repos whose remote points at that host to the work identity.
                    # Two patterns cover SSH (git@...) and HTTPS URL forms.
                    printf '\n[includeIf "hasconfig:remote.*.url:git@%s:*/**"]\n\tpath = ~/.gitconfig-work\n[includeIf "hasconfig:remote.*.url:https://*%s/**"]\n\tpath = ~/.gitconfig-work\n' \
                        "$whost" "$whost" >> "$GITLOCAL"
                    echo "  wrote $HOME/.gitconfig-work and routing rules into $GITLOCAL"
                    echo "  Tip: route SSH keys per host in ~/.ssh/config (see README)."
                    # hasconfig includes need git >= 2.36 (silently ignored before).
                    gv="$(git --version 2>/dev/null | sed -n 's/git version \([0-9]*\.[0-9]*\).*/\1/p')"
                    case "$gv" in
                        1.*|2.[0-9]|2.[12][0-9]|2.3[0-5])
                            echo "  ! git $gv is too old for hasconfig includes (needs >= 2.36):"
                            echo "    the work identity will not activate until git is upgraded." ;;
                    esac
                fi
                ;;
        esac
    else
        echo "No TTY: create $GITLOCAL with your [user] name/email."
    fi
fi

# Install the CLI tools the nvim/zellij/yazi configs use (idempotent;
# best-effort). Skip entirely with SKIP_DEPS=1. See install_deps.sh.
if [ "${SKIP_DEPS:-0}" != "1" ] && [ -x "$DOTFILES/install_deps.sh" ]; then
    if [ -t 0 ]; then
        printf "\nInstall/upgrade developer tools now (nvim, zellij, yazi, fzf, ripgrep, ruff, ty, glow)? [Y/n]: "
        read -r ans
    else
        ans="y"  # non-interactive: assume yes
    fi
    case "${ans:-y}" in
        [Nn]*) echo "Skipping tool install (run ./install_deps.sh anytime)." ;;
        *)     "$DOTFILES/install_deps.sh" ;;
    esac
fi

source ~/."$SYMLINK_BASENAME"

# Don't leak helpers/temp vars into the live shell when sourced.
unset -f backup 2>/dev/null
unset name email ans whost wname wemail gv file rc dir target \
      ZJURL ZJCACHE ZJPERM \
      EXISTING_NAME EXISTING_EMAIL GITLOCAL SYMLINK_BASENAME DOTFILES_BKP 2>/dev/null
