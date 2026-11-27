mkdir -p "$HOME/.local/state/zsh" "$HOME/.cache/zsh"
HISTFILE="$HOME/.local/state/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks
setopt autocd interactive_comments extended_glob no_beep

export EDITOR=nvim VISUAL=nvim PAGER=less
export BAT_THEME=ansi
typeset -U path
path=("$HOME/.local/bin" $path)

autoload -Uz compinit
compinit -d "$HOME/.cache/zsh/zcompdump"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''

bindkey -e
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^H'      backward-kill-word

alias ls='eza --group-directories-first'
alias ll='eza -la --group-directories-first --git'
alias lt='eza --tree --level=2 --group-directories-first'
alias v='nvim'
alias g='git'
alias grep='grep --color=auto'
alias update='paru -Syu'
alias cleanup='paru -Rns $(paru -Qdtq) 2>/dev/null; paru -Sc --noconfirm'

export FZF_DEFAULT_OPTS='--color=bg+:#1f1f1f,bg:-1,fg:#a0a0a0,fg+:#ededed,hl:#ffffff,hl+:#ffffff,prompt:#6b6b6b,pointer:#ededed,marker:#ededed,info:#4f4f4f,border:#3a3a3a --border=sharp --height=40% --layout=reverse'
source <(fzf --zsh)
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#4f4f4f'
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
