# Common settings for both Bash and Zsh.
# Environment (PATH, EDITOR, conda) is set first so scripts and `ssh host cmd`
# shells get it; everything interactive-only lives below the `case $-` guard.

# Check if running Zsh or Bash
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    SHELL_TYPE="unknown"
fi

# Prepend a dir to PATH only if it exists and isn't already there
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) [ -d "$1" ] && PATH="$1:$PATH" ;;
    esac
}
path_prepend "/usr/local/bin"
path_prepend "$HOME/bin"
# ~/.local/bin holds uv-installed tools (ruff, ty) and any release binaries
# install_deps.sh drops there (nvim/fzf/zellij/yazi on Linux); keep it ahead of
# system paths so a current nvim wins over an older apt one.
path_prepend "$HOME/.local/bin"
export PATH

# uv's env file (adds its bin dir; only if installed on this machine)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

# Default editor: prefer neovim, fall back to vim (works on every box).
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim
    export VISUAL=nvim
else
    export EDITOR=vim
    export VISUAL=vim
fi

# Fix less issue in Docker
export LESS="-R"

# Faster Docker builds
export COMPOSE_BAKE=true

# Conda (lazy): nothing conda-related runs at startup; the first `conda` call
# initializes it. Detects common install prefixes — override with CONDA_HOME,
# disable with NO_CONDA=1. A conda that is merely on PATH (unlisted prefix) is
# resolved lazily too, so startup never pays for `conda info --base` (~1s).
if [ -z "${NO_CONDA:-}" ]; then
    __CONDA_ROOT=""
    for __d in "${CONDA_HOME:-}" "$HOME/anaconda3" "$HOME/miniconda3" "$HOME/miniforge3" \
               "$HOME/mambaforge" "$HOME/opt/anaconda3" "$HOME/opt/miniconda3" \
               "/opt/homebrew/Caskroom/miniconda/base" "/opt/homebrew/Caskroom/miniforge/base" \
               "/usr/local/Caskroom/miniconda/base" "/usr/local/Caskroom/miniforge/base" \
               "/opt/conda"; do
        [ -n "$__d" ] && [ -x "$__d/bin/conda" ] && { __CONDA_ROOT="$__d"; break; }
    done
    unset __d
    if [ -n "$__CONDA_ROOT" ] || command -v conda >/dev/null 2>&1; then
        conda() {
            unset -f conda
            local s="$SHELL_TYPE"; [ "$s" = "unknown" ] && s="bash"
            # Deferred from startup: resolve a PATH-only conda now.
            [ -z "$__CONDA_ROOT" ] && __CONDA_ROOT="$(conda info --base 2>/dev/null)"
            local hook=""
            [ -x "$__CONDA_ROOT/bin/conda" ] && hook="$("$__CONDA_ROOT/bin/conda" "shell.$s" hook 2>/dev/null)"
            if [ -n "$hook" ]; then
                eval "$hook"
            else
                echo "conda: failed to initialize from ${__CONDA_ROOT:-PATH}" >&2
            fi
            conda "$@"   # the hook's real function, or the PATH binary as fallback
        }
    fi
fi

# ---------------------------------------------------------------------------
# Interactive shells only below: prompt, aliases, history, completions, tool
# keybindings. Non-interactive shells (scripts, scp, `ssh host cmd` — which
# Debian bash points at this file) stop here and stay fast.
# ---------------------------------------------------------------------------
case $- in *i*) ;; *) return ;; esac

# Set a cross-shell PS1 prompt
if [ "$SHELL_TYPE" = "bash" ]; then
    PS1="\[\e[32m\]\u:\w\[\e[m\]\$ "
elif [ "$SHELL_TYPE" = "zsh" ]; then
    PS1="%F{green}%n:%~%f$ "
fi

# Source alias file if it exists
if [ -f "$HOME/.aliases" ]; then
    source "$HOME/.aliases"
fi

# History settings (persisted and de-duplicated in both shells)
HISTSIZE=10000
if [ "$SHELL_TYPE" = "bash" ]; then
    HISTFILESIZE=20000
    HISTCONTROL=ignoreboth      # ignore duplicate and space-prefixed commands
    shopt -s histappend         # append to history instead of overwriting
elif [ "$SHELL_TYPE" = "zsh" ]; then
    HISTFILE="$HOME/.zsh_history"
    SAVEHIST=20000
    setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE
fi

# Completion
if [ "$SHELL_TYPE" = "bash" ]; then
    [ -f /etc/bash_completion ] && . /etc/bash_completion
elif [ "$SHELL_TYPE" = "zsh" ]; then
    autoload -U compinit && compinit -C   # -C skips the slow security check
fi

# VS Code from the terminal. Prefer the app bundle's real CLI (so flags like
# --wait/--diff/-g work); `open -a` is the last resort and takes no flags.
vscode() {
    local cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
    if [ -x "$cli" ]; then
        "$cli" "$@"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        open -a "Visual Studio Code" "$@"
    else
        command code "$@"
    fi
}
alias code="vscode"

# yazi: terminal file manager. Use `y` (not plain `yazi`) so that on quit your
# shell cd's to the directory you ended up in — the wrapper Yazi documents.
if command -v yazi >/dev/null 2>&1; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t yazi-cwd.XXXXXX)"
        yazi "$@" --cwd-file="$tmp"
        cwd="$(cat -- "$tmp")"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd -- "$cwd"
        rm -f -- "$tmp"
    }
fi

# uv shell completion (only if installed on this machine)
if command -v uv >/dev/null 2>&1 && [ "$SHELL_TYPE" != "unknown" ]; then
    eval "$(uv generate-shell-completion "$SHELL_TYPE")"
fi

# zoxide: smarter directory jumping. Learns dirs as you cd; jump with a fragment
# (`zz dotf`), pick interactively with `zzi`. Uses `--cmd zz` rather than the
# default `z`, leaving bare `z` free for zellij (see ~/.aliases). cd is untouched.
if command -v zoxide >/dev/null 2>&1 && [ "$SHELL_TYPE" != "unknown" ]; then
    eval "$(zoxide init --cmd zz "$SHELL_TYPE")"
fi

# fzf keybindings + completion: Ctrl-R fuzzy history, Ctrl-T fuzzy file insert,
# Alt-C fuzzy cd. Needs fzf >= 0.48 for --bash/--zsh (install_deps.sh installs
# a current release where the distro's is older); an old fzf just no-ops here.
if command -v fzf >/dev/null 2>&1 && [ "$SHELL_TYPE" != "unknown" ]; then
    eval "$(fzf --"$SHELL_TYPE" 2>/dev/null)"
fi

# Tab completion for the zellij helpers (see ~/.aliases): za/zk/zd complete local
# session names; `zssh` completes SSH hosts (arg 1, from ~/.ssh/config) and then
# that host's session names (arg 2, fetched over SSH). Matching is substring +
# case-insensitive (`bear` completes `great-bear`), scoped to just these commands.
if command -v zellij >/dev/null 2>&1; then
    if [ "$SHELL_TYPE" = "zsh" ]; then
        # -M spec: case-insensitive (m:) + match anywhere in the word (l:/r:), so
        # `bear` completes `great-bear`. Single-quoted -> one arg regardless of opts.
        _zj_sessions() { compadd -M 'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*' -- ${(f)"$(zellij list-sessions -ns 2>/dev/null)"}; }
        compdef _zj_sessions za zk zd 2>/dev/null
        _zssh() {
            if (( CURRENT == 2 )); then
                local -a hosts
                hosts=(${(f)"$(awk 'tolower($1)=="host"{for (i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null)"})
                compadd -M 'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*' -- $hosts
            elif (( CURRENT == 3 )); then
                local out; local -a sess
                out="$(ssh -o ConnectTimeout=2 -o BatchMode=yes -- $words[2] 'zellij list-sessions -ns' 2>/dev/null)"
                if (( $? == 255 )); then
                    _message -r "${words[2]} unreachable"          # empty vs unreachable are now distinct
                else
                    sess=(${(f)out})
                    (( ${#sess} )) && compadd -M 'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*' -- $sess \
                                    || _message -r "no sessions on ${words[2]} (type a directory to start one)"
                fi
            fi
        }
        compdef _zssh zssh 2>/dev/null
    elif [ "$SHELL_TYPE" = "bash" ]; then
        # grep -iF gives case-insensitive substring matching (bear -> great-bear).
        _zj_sessions() {
            COMPREPLY=($(zellij list-sessions -ns 2>/dev/null | grep -iF -- "${COMP_WORDS[COMP_CWORD]}"))
        }
        complete -F _zj_sessions za zk zd
        _zssh() {
            local cur="${COMP_WORDS[COMP_CWORD]}"
            if [ "$COMP_CWORD" -eq 1 ]; then
                COMPREPLY=($(awk 'tolower($1)=="host"{for (i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null | grep -iF -- "$cur"))
            elif [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(ssh -o ConnectTimeout=2 -o BatchMode=yes -- "${COMP_WORDS[1]}" 'zellij list-sessions -ns' 2>/dev/null | grep -iF -- "$cur"))
            fi
        }
        complete -F _zssh zssh
    fi
fi

# Machine-local overrides: secrets, work tools, per-host aliases.
# Lives only in $HOME, never tracked here. Sourced last so it can override.
# (if-form, not `&&`: keeps this file's exit status 0 when no override exists)
if [ -f "$HOME/.bashrc.local" ]; then
    source "$HOME/.bashrc.local"
fi
