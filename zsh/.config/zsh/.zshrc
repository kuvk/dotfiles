# PROMPT
eval "$(starship init zsh)"

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
fpath=($HOME/src/zsh-completions/src $fpath)
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

## ZSH VI MODE
source $(brew --prefix)/opt/zsh-vi-mode/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
# ## cursor style for vi mode
ZVM_INSERT_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BEAM
ZVM_NORMAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_OPPEND_MODE_CURSOR=$ZVM_CURSOR_BLINKING_UNDERLINE
ZVM_VISUAL_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_VISUAL_LINE_MODE_CURSOR=$ZVM_CURSOR_BLINKING_BLOCK
ZVM_VI_INSERT_ESCAPE_BINDKEY=jk

# HISTORY AND AUTOSUGGESTIONS
source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source $(brew --prefix)/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# Mappings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

#bindkey '^I' autosuggest-accept

export EDITOR="nvim"

if [[ -d "$HOME/.tmux/plugins/tmuxifier" ]]; then
    export PATH="$HOME/.tmux/plugins/tmuxifier/bin:$PATH"
    eval "$(tmuxifier init -)"
    # Tmux
    alias tmuxa="tmux attach"
    alias tmuxd="tmux detach"
    # Tmuxifier
    alias tnew="tmuxifier new-session"
    alias tedit="tmuxifier edit-session"
    alias tload="tmuxifier load-session"
fi

# ALIASES
alias cl="clear"
alias ll="lsd -la"
alias ls="lsd"
alias cat="bat --paging=never"
alias top="htop"

# Syntax highlighting plugin goes last
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
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

# Set up fzf key bindings and fuzzy completion
eval "$(fzf --zsh)"
