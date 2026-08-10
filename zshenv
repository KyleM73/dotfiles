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

# mosh-server refuses to start without a UTF-8 locale. ssh clients usually
# forward LANG/LC_* (sshd's AcceptEnv), but default one when they don't.
# On Linux the locale must also be generated (locale-gen en_US.UTF-8).
: "${LANG:=en_US.UTF-8}"
export LANG
