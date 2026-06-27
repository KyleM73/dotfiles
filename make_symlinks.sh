# Symlinks the dotfiles into $HOME and sets up local git identity.
# Run from the repo: ./make_symlinks.sh   (or: source make_symlinks.sh to reload now)

# Resolve this script's directory in both Zsh and Bash
if [ -n "$ZSH_VERSION" ]; then
    DOTFILES="$(cd "$(dirname "${(%):-%N}")" && pwd)"
    SYMLINK_BASENAME="zshrc"
else
    DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    SYMLINK_BASENAME="bashrc"
fi

DOTFILES_BKP=~/dotfiles.bkp
files="aliases vimrc screenrc gitconfig"  # files to symlink into $HOME

# Capture existing git identity before ~/.gitconfig is replaced
EXISTING_NAME="$(git config --global user.name 2>/dev/null)"
EXISTING_EMAIL="$(git config --global user.email 2>/dev/null)"

mkdir -p "$DOTFILES_BKP"
cd "$DOTFILES" || exit 1

# Back up real files (not our own symlinks), then link
echo "Linking dotfiles into $HOME (backups in $DOTFILES_BKP)"
for file in $files; do
    [ -e ~/."$file" ] && [ ! -L ~/."$file" ] && mv ~/."$file" "$DOTFILES_BKP"
    ln -sf "$DOTFILES/$file" ~/."$file"
    echo "  ~/.$file -> $DOTFILES/$file"
done

# Both shells share the same rc file
for rc in bashrc zshrc; do
    [ -e ~/."$rc" ] && [ ! -L ~/."$rc" ] && mv ~/."$rc" "$DOTFILES_BKP"
    ln -sf "$DOTFILES/bashrc" ~/."$rc"
    echo "  ~/.$rc -> $DOTFILES/bashrc"
done

# XDG config directories (nvim, yazi, zellij) -> ~/.config/<name>
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dirs="nvim yazi zellij"  # dirs under repo config/ to link into ~/.config
mkdir -p "$XDG_CONFIG"
echo "Linking config dirs into $XDG_CONFIG"
for dir in $config_dirs; do
    target="$XDG_CONFIG/$dir"
    # Back up a real (non-symlink) existing dir, then link. -n stops ln from
    # nesting the link inside an existing symlinked dir on re-run.
    [ -e "$target" ] && [ ! -L "$target" ] && mv "$target" "$DOTFILES_BKP/"
    ln -sfn "$DOTFILES/config/$dir" "$target"
    echo "  $target -> $DOTFILES/config/$dir"
done

# Local git identity (untracked; never committed)
GITLOCAL="$HOME/.gitconfig.local"
if [ ! -f "$GITLOCAL" ]; then
    if [ -t 0 ]; then
        echo
        echo "Setting up personal git identity in $GITLOCAL"
        printf "  Full name [%s]: " "$EXISTING_NAME"; read -r name
        printf "  Email [%s]: " "$EXISTING_EMAIL"; read -r email
        name="${name:-$EXISTING_NAME}"
        email="${email:-$EXISTING_EMAIL}"
        printf '[user]\n\tname = %s\n\temail = %s\n' "$name" "$email" > "$GITLOCAL"
        echo "  wrote $GITLOCAL"

        # Optional work identity, auto-selected by remote host (kept untracked)
        printf "\nSet up a separate work git identity for a specific host? [y/N]: "; read -r ans
        case "$ans" in
            [Yy]*)
                printf "  Work git host (e.g. github.com, gitlab.com, company domain): "; read -r whost
                printf "  Work name [%s]: " "$name"; read -r wname
                printf "  Work email: "; read -r wemail
                printf '[user]\n\tname = %s\n\temail = %s\n' \
                    "${wname:-$name}" "$wemail" > "$HOME/.gitconfig-work"
                # Route repos whose remote points at that host to the work identity.
                # Two patterns cover SSH (git@...) and HTTPS URL forms.
                printf '\n[includeIf "hasconfig:remote.*.url:git@%s:*/**"]\n\tpath = ~/.gitconfig-work\n[includeIf "hasconfig:remote.*.url:https://*%s/**"]\n\tpath = ~/.gitconfig-work\n' \
                    "$whost" "$whost" >> "$GITLOCAL"
                echo "  wrote $HOME/.gitconfig-work and routing rules into $GITLOCAL"
                echo "  Tip: route SSH keys per host in ~/.ssh/config (see README)."
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
        printf "\nInstall/upgrade developer tools now (nvim, zellij, yazi, fzf, ripgrep, ruff, ty)? [Y/n]: "
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
