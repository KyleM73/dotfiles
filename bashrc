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
    PS1="\[\e[32m\]\u@\h:\w\[\e[m\]\$ "
elif [ "$SHELL_TYPE" = "zsh" ]; then
    PS1="%F{green}%n@%m:%~%f$ "
fi

# Source alias file if it exists
if [ -f "$HOME/.aliases" ]; then
    source "$HOME/.aliases"
fi

# Anaconda settings
# if [ -d "$HOME/anaconda3" ]; then
#     __conda_setup="$("$HOME/anaconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
#     eval "$__conda_setup"
#     unset __conda_setup
# fi

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
export PATH="$HOME/anaconda3/bin:$HOME/bin:/usr/local/bin:$PATH"

# Fix less issue in Docker
export LESS="-R"
