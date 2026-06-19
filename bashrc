# Common settings for both Bash and Zsh

# Check if running Zsh or Bash
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    SHELL_TYPE="unknown"
fi

# Set a cross-shell PS1 prompt
if [ "$SHELL_TYPE" = "bash" ]; then
    # Old prompt (with hostname): PS1="\[\e[32m\]\u@\h:\w\[\e[m\]\$ "
    PS1="\[\e[32m\]\u:\w\[\e[m\]\$ "
elif [ "$SHELL_TYPE" = "zsh" ]; then
    # Old prompt (with hostname): PS1="%F{green}%n@%m:%~%f$ "
    PS1="%F{green}%n:%~%f$ "
fi

# Source alias file if it exists
if [ -f "$HOME/.aliases" ]; then
    source "$HOME/.aliases"
fi

# Conda (lazy): not loaded at startup; the first `conda` call initializes it.
# Detects common install prefixes; override with CONDA_HOME, disable with NO_CONDA=1.
if [ -z "$NO_CONDA" ]; then
    for __d in "$CONDA_HOME" "$HOME/anaconda3" "$HOME/miniconda3" "$HOME/miniforge3" \
               "$HOME/mambaforge" "$HOME/opt/anaconda3" "$HOME/opt/miniconda3" \
               "/opt/homebrew/Caskroom/miniconda/base" "/opt/homebrew/Caskroom/miniforge/base" \
               "/usr/local/Caskroom/miniconda/base" "/usr/local/Caskroom/miniforge/base" \
               "/opt/conda"; do
        [ -x "$__d/bin/conda" ] && { __CONDA_ROOT="$__d"; break; }
    done
    # Fall back to a conda already on PATH (e.g. Homebrew/system install)
    [ -z "$__CONDA_ROOT" ] && command -v conda >/dev/null 2>&1 && \
        __CONDA_ROOT="$(conda info --base 2>/dev/null)"
    unset __d
    if [ -n "$__CONDA_ROOT" ]; then
        conda() {
            unset -f conda
            local s="$SHELL_TYPE"; [ "$s" = "unknown" ] && s="bash"
            eval "$("$__CONDA_ROOT/bin/conda" "shell.$s" hook)"
            conda "$@"
        }
    fi
fi

# History settings
HISTSIZE=10000
HISTFILESIZE=20000

# Bash/Zsh-specific settings
if [ "$SHELL_TYPE" = "bash" ]; then
    # Enable Bash completion
    if [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
elif [ "$SHELL_TYPE" = "zsh" ]; then
    autoload -U compinit
    compinit
fi

# Add custom paths (e.g., Anaconda, Docker)
[ -d "$HOME/anaconda3/bin" ] && export PATH="$HOME/anaconda3/bin:$PATH"
export PATH="$HOME/bin:/usr/local/bin:$PATH"

# Fix less issue in Docker
export LESS="-R"

# Faster Docker builds
export COMPOSE_BAKE=true

# App Aliases
vscode() {
  if [[ "$OSTYPE" == "darwin"* ]]; then
    open -a "Visual Studio Code" "$@"
  else
    command code "$@"
  fi
}
alias code="vscode"

# uv (only if installed on this machine)
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
if command -v uv >/dev/null 2>&1 && [ "$SHELL_TYPE" != "unknown" ]; then
    eval "$(uv generate-shell-completion "$SHELL_TYPE")"
fi

# Machine-local overrides: secrets, work tools, per-host aliases.
# Lives only in $HOME, never tracked here. Sourced last so it can override.
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
