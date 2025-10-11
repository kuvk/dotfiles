# PROMPT
eval "$(starship init zsh)"
if [[ "$(uname)" == "Darwin" ]]; then
    export STARSHIP_CONFIG=~/.config/starship.toml
fi

setopt NOBEEP
setopt inc_append_history
setopt extended_history
setopt hist_find_no_dups
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt interactive_comments
setopt auto_cd

HISTSIZE=100000
SAVEHIST=100000
HISTFILE=${ZDOTDIR}/.zsh_history

# Use modern completion system
fpath=($HOME/.local/share/zsh-plugins/zsh-completions/src $fpath)
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)
# eval "$(dircolors -b)"
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
if [[ "$(uname)" == "Linux" ]]; then
    eval $(dircolors -b ${ZDOTDIR}/.dir_colors)
fi
LS_COLORS="$LS_COLORS:ma=42;30"
export LS_COLORS
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

## ZSH VI MODE
source $HOME/.local/share/zsh-plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh
# yank to clipboard linux
if [[ "$(uname)" == "Linux" ]]; then
    zvm_vi_yank() {
        zvm_yank
        if [[ -n "$WAYLAND_DISPLAY" ]] && command -v wl-copy >/dev/null 2>&1; then
            printf %s "${CUTBUFFER}" | wl-copy
        else
            printf %s "${CUTBUFFER}" | xclip -sel c
        fi

        zvm_exit_visual_mode
    }
# macOS
else 
    zvm_vi_yank() {
        zvm_yank
        printf %s "${CUTBUFFER}" | pbcopy -i
        zvm_exit_visual_mode
    }
fi

## cursor style for vi mode
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_VI_HIGHLIGHT_BACKGROUND=black
ZVM_VI_HIGHLIGHT_FOREGROUND=green
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

# HISTORY AND AUTOSUGGESTIONS
source $HOME/.local/share/zsh-plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source $HOME/.local/share/zsh-plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Mappings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
# bindkey '^I' autosuggest-accept

# Tmuxifier
if [[ -d "$HOME/.tmux/plugins/tmuxifier" ]]; then
    export PATH="$HOME/.tmux/plugins/tmuxifier/bin:$PATH"
    eval "$(tmuxifier init -)"

    # tmuxifier layout path
    export TMUXIFIER_LAYOUT_PATH="$HOME/.tmux-layouts"

    alias tnew="tmuxifier new-session"
    alias tedit="tmuxifier edit-session"
    alias tload="tmuxifier load-session"
fi

# Spicetify
if [[ -d "$HOME/.spicetify" ]]; then
    export PATH=$PATH:$HOME.spicetify
fi

# Pyenv
if [[ -d "$HOME/.pyenv" ]]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"

# ALIASES
alias ll="lsd -la"
alias l="lsd -l"
alias ls="lsd"
alias cat="bat --style=plain,header,grid"
alias top="btop"
alias nv="nvim"
alias fzf="fzf --preview='bat --color=always --style=plain,header,grid {}'"
alias tmuxa="tmux attach"
alias tmuxd="tmux detach"
alias ip="ip --color=auto"
alias grep="grep --color=auto"
alias fgrep="fgrep --color=auto"
alias diff="diff --color=auto"
alias paccheck="pacman -Qq | fzf --preview 'pacman -Qil {}' --layout=reverse --bind 'enter:execute(pacman -Qil {} | less)'"
alias c++="c++ -std=c++23 -Wall -Wextra -Wconversion -Wsign-conversion --pedantic-errors -ggdb"

# Syntax highlighting plugin goes last
source $HOME/.local/share/zsh-plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
(( ${+ZSH_HIGHLIGHT_STYLES} )) || typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[path]=fg=blue
ZSH_HIGHLIGHT_STYLES[path_prefix]=fg=blue
ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=blue
ZSH_HIGHLIGHT_STYLES[precommand]=fg=magenta
ZSH_HIGHLIGHT_STYLES[alias]=fg=green
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=cyan
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=cyan
ZSH_HIGHLIGHT_STYLES[redirection]=fg=yellow
ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=yellow
ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red

eval "$(direnv hook zsh)"
