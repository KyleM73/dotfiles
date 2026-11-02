# Sourced by EVERY zsh: login, interactive, and non-interactive — including
# `ssh host cmd` and mosh-server launches. Non-interactive zsh reads ONLY this
# file (never .zshrc), so anything a bare ssh remote command needs must be
# here. Keep it minimal and silent: PATH and locale only; everything else
# lives in bashrc (-> ~/.zshrc).

# Homebrew (macOS arm64 / intel / Linuxbrew) and locally installed tools
# (install_deps.sh and uv drop binaries in ~/.local/bin). Skips dirs that
# don't exist or are already on PATH.
for _d in /opt/homebrew/sbin /opt/homebrew/bin /usr/local/bin \
          /home/linuxbrew/.linuxbrew/bin "$HOME/.local/bin"; do
    case ":$PATH:" in
        *":$_d:"*) ;;
        *) [ -d "$_d" ] && PATH="$_d:$PATH" ;;
    esac
done
unset _d
export PATH

# zellij sockets (Linux): keep them out of /run/user/$UID, which is wiped when
# the user manager stops, so sessions kept alive by zpersist stay attachable.
# Every zellij command (incl. `ssh host zellij ...`) must agree on this, so
# bashrc, zshenv and zweb-boot.sh all set it. See config/zellij/zpersist.sh.
case "${OSTYPE-}" in linux*) export ZELLIJ_SOCKET_DIR="$HOME/.local/state/zellij/sock" ;; esac

# mosh-server refuses to start without a UTF-8 locale. ssh clients usually
# forward LANG/LC_* (sshd's AcceptEnv), but default one when they don't.
# On Linux the locale must also be generated (locale-gen en_US.UTF-8).
: "${LANG:=en_US.UTF-8}"
export LANG
