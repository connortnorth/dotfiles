# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set the directory we want to store zinit and plugins
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download Zinit, if it's not there yet
if [ ! -d "$ZINIT_HOME" ]; then
   mkdir -p "$(dirname $ZINIT_HOME)"
   git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

# Source/Load zinit
source "${ZINIT_HOME}/zinit.zsh"

# Add in Powerlevel10k
zinit ice depth=1; zinit light romkatv/powerlevel10k

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add in snippets
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

zinit cdreplay -q

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Aliases
alias ls='ls --color'
alias c='clear'
alias l='exit'
alias py='python'
hash -d wps=/home/conman/connor-config/wallpapers
alias rwp='wp r'

wp() {
    if [[ "$1" == "-r" || "$1" == "r" ]]; then

        local dir="${2:-$HOME/connor-config/wallpapers}"

        if [[ ! -d "$dir" ]]; then
            echo "Error: Directory '$dir' does not exist." >&2
            return 1
        fi

        # Extract the currently active wallpaper path from Plasma's config file
        local current_wp=""
        if [[ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]]; then
            current_wp=$(grep -m 1 "^Image=" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" | cut -d '=' -f 2- | sed 's|^file://||')
        fi

        # Find a random image, excluding hidden files and the current wallpaper
        local random_img
        random_img=$(find "$dir" -maxdepth 1 -type f -not -path '*/.*' -not -path "$current_wp" | shuf -n 1)

        # Fallback: If only 1 wallpaper exists, find won't match anything when excluding current_wp.
        # Pick any valid image in that case so the command doesn't fail.
        if [[ -z "$random_img" ]]; then
            random_img=$(find "$dir" -maxdepth 1 -type f -not -path '*/.*' | shuf -n 1)
        fi

        if [[ -n "$random_img" ]]; then
            plasma-apply-wallpaperimage "$random_img"
            chafa "$random_img"
        else
            echo "Error: No valid image files found in '$dir'." >&2
            return 1
        fi

    elif [[ "$1" == "-s" || "$1" == "s" ]]; then

        local dir="${2:-$HOME/connor-config/wallpapers}"

        if [[ ! -d "$dir" ]]; then
            echo "Error: Directory '$dir' does not exist." >&2
            return 1
        fi

        # Use find to locate files and rofi in dmenu mode for interactive selection
        local selected_img
        selected_img=$(find "$dir" -maxdepth 1 -type f -not -path '*/.*' | rofi -dmenu -i -p "Select Wallpaper:")

        if [[ -n "$selected_img" ]]; then
            plasma-apply-wallpaperimage "$selected_img"
            chafa "$selected_img"
        fi

    else
        # Pass the provided argument directly to plasma-apply-wallpaperimage
        plasma-apply-wallpaperimage "$1"
        chafa "$1"
    fi
}

stownew() {
    # Help message function
    show_help() {
        echo "Usage: stownew <file_or_folder>"
        echo ""
        echo "Moves a file or folder into ~/.dotfiles under a Stow package"
        echo "and symlinks it back to its original path."
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help message"
        echo ""
        echo "Examples:"
        echo "  stownew ~/.zshrc"
        echo "  stownew ~/.config/nvim"
        echo "  stownew ~/.config/nvim/lua/init.lua"
    }

    # Show help if no arguments passed or if -h/--help is requested
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        return 0
    fi

    local target="$1"
    local dotfiles_dir="$HOME/connor-config"

    # Ensure target exists
    if [ ! -e "$target" ]; then
        echo "Error: Path '$target' does not exist."
        return 1
    fi

    # Resolve absolute path and relative path from HOME
    local abs_path
    abs_path=$(realpath "$target")

    # Check if target is inside HOME
    case "$abs_path" in
        "$HOME"*) ;;
        *)
            echo "Error: Target must be inside your home directory ($HOME)."
            return 1
            ;;
    esac

    local rel_path="${abs_path#$HOME/}"

    # Verify target is not already inside dotfiles_dir
    local abs_dotfiles
    abs_dotfiles=$(realpath "$dotfiles_dir" 2>/dev/null || echo "$dotfiles_dir")
    case "$abs_path" in
        "$abs_dotfiles"*)
            echo "Error: Target is already inside your dotfiles directory."
            return 1
            ;;
    esac

    # Determine package name and relative destination path inside the package
    local pkg_name
    local rel_dest

    local first_part
    first_part=$(echo "$rel_path" | cut -d'/' -f1)

    if [ "$first_part" = ".config" ]; then
        # E.g., .config/nvim/init.lua -> pkg_name: nvim, rel_dest: .config/nvim/init.lua
        pkg_name=$(echo "$rel_path" | cut -d'/' -f2)
        if [ -z "$pkg_name" ]; then
            echo "Error: Cannot target ~/.config directory itself."
            return 1
        fi
        rel_dest="$rel_path"
    else
        # E.g., .zshrc -> pkg_name: zsh, rel_dest: .zshrc
        # E.g., .local/bin/script -> pkg_name: local, rel_dest: .local/bin/script
        pkg_name=$(echo "$first_part" | sed 's/^\.//')
        rel_dest="$rel_path"
    fi

    # Destination paths inside dotfiles
    local package_dir="$dotfiles_dir/$pkg_name"
    local full_dest="$package_dir/$rel_dest"
    local dest_parent_dir
    dest_parent_dir=$(dirname "$full_dest")

    # Prevent overwriting existing files in dotfiles
    if [ -e "$full_dest" ]; then
        echo "Error: Destination '$full_dest' already exists in dotfiles."
        return 1
    fi

    # Create destination parent directory tree and move the item
    mkdir -p "$dest_parent_dir"
    mv "$abs_path" "$full_dest"

    # Restow package
    if (cd "$dotfiles_dir" && stow --restow "$pkg_name"); then
        echo "Successfully moved and stowed:"
        echo "  Source: $abs_path"
        echo "  Package: $pkg_name -> $full_dest"
    else
        echo "Warning: Move succeeded, but 'stow' failed. Check for symlink conflicts in $HOME."
        return 1
    fi
}

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"
