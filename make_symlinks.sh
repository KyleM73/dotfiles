# Check if the current shell is Zsh
if [ -n "$ZSH_VERSION" ]; then
    # Get the directory of the current script in Zsh
    DOTFILES="$(cd "$(dirname "${(%):-%N}")" && pwd)"
    SYMLINK_BASENAME="zshrc"  # Use 'zshrc' for Zsh
else
    # Get the directory of the current script in Bash
    DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SYMLINK_BASENAME="bashrc"  # Use 'bashrc' for Bash
fi

DOTFILES_BKP=~/dotfiles.bkp
files="aliases vimrc screenrc"  # list of files/folders to symlink in homedir

# Create DOTFILES_BKP in homedir
mkdir -p "$DOTFILES_BKP"

# Change to the dotfiles directory
cd "$DOTFILES" || exit 1

# Move any existing dotfiles in homedir to DOTFILES_BKP directory
echo "Moving any existing dotfiles from ~ to $DOTFILES_BKP"
for file in $files; do
    [ -f ~/.$file ] && mv ~/.$file "$DOTFILES_BKP"  # Only move if the file exists
    echo "Creating symlink to $file in home directory."
    ln -sf "$DOTFILES/$file" ~/.$file  # Force symlink creation
done

# Handle the special case for bashrc/zshrc
if [ -n "$ZSH_VERSION" ]; then
    # If Zsh, create symlink for bashrc as zshrc
    echo "Creating symlink to $SYMLINK_BASENAME in home directory."
    ln -sf "$DOTFILES/bashrc" ~/.$SYMLINK_BASENAME
fi
