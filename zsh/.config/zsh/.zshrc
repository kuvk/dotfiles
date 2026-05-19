case "$OSTYPE" in
    darwin*) _OS="Darwin" ;;
    linux*)  _OS="Linux" ;;
    *)       _OS="$(uname)" ;;
esac

## Starship
if command -v starship >/dev/null; then
    export STARSHIP_LOG=error
    if [[ "$_OS" == "Darwin" ]]; then
        export STARSHIP_CONFIG=~/.config/starship.toml
    fi
    eval "$(starship init zsh)"
fi

## Options / history
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

## Completions
fpath=($HOME/.local/share/zsh-plugins/zsh-completions/src $fpath)

autoload -Uz compinit
zmodload zsh/complist

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

if [[ "$_OS" == "Linux" ]]; then
    eval "$(dircolors -b ${ZDOTDIR}/.dir_colors)"
fi
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

ZCOMPDUMP_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
ZCOMPDUMP="${ZCOMPDUMP_DIR}/zcompdump-${ZSH_VERSION}"
mkdir -p "$ZCOMPDUMP_DIR"

if [[ "$_OS" == "Linux" ]]; then
    _zcompdump_mtime=$(stat -c %Y "$ZCOMPDUMP" 2>/dev/null || echo 0)
else
    # Fallback: no mtime check; still benefits from cached location + -C
    _zcompdump_mtime=0
fi

if [[ ! -f "$ZCOMPDUMP" || $(( $(date +%s) - _zcompdump_mtime )) -gt 86400 ]]; then
    compinit -d "$ZCOMPDUMP"
else
    compinit -C -d "$ZCOMPDUMP"
fi
unset _zcompdump_mtime

_comp_options+=(globdots)

## ZSH VI MODE
source $HOME/.local/share/zsh-plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# yank to clipboard
if [[ "$_OS" == "Linux" ]]; then
    zvm_vi_yank() {
        zvm_yank
        if [[ -n "$WAYLAND_DISPLAY" ]] && command -v wl-copy >/dev/null 2>&1; then
            printf %s "${CUTBUFFER}" | wl-copy
        else
            printf %s "${CUTBUFFER}" | xclip -sel c
        fi
        zvm_exit_visual_mode
    }
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

# Local
if [[ -d "$HOME/.local/bin" ]]; then
    PATH="$HOME/.local/bin:$PATH"
fi

# Tmuxifier
if [[ -d "$HOME/.tmux/plugins/tmuxifier" ]]; then
    export PATH="$HOME/.tmux/plugins/tmuxifier/bin:$PATH"
    eval "$(tmuxifier init -)"

    export TMUXIFIER_LAYOUT_PATH="$HOME/.tmux-layouts"
    alias tnew="tmuxifier new-session"
    alias tedit="tmuxifier edit-session"
    alias tload="tmuxifier load-session"
fi

# Spicetify
if [[ -d "$HOME/.config/.spicetify" ]]; then
    export PATH="$HOME/.config/spicetify:$PATH"
fi

# Pyenv
if [[ -d "$HOME/.pyenv" ]]; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi

# Cargo
if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Set up fzf
eval "$(fzf --zsh)"

# ALIASES
alias ll="lsd -lA"
alias l="lsd -l"
alias ls="ls --color=auto"
alias cat="bat --style=plain,header,grid"
alias dots="cd \"$HOME/dotfiles\""
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

if [[ "$TERM" = "xterm-kitty" ]]; then
    alias ssh="TERM=xterm-256color ssh"
fi

# Syntax highlighting
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

# if [[ -o interactive ]]; then
#     fastfetch
# fi
