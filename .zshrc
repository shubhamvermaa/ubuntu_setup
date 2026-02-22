# PROMPT='%~ ❯ '
# PROMPT='%F{white}%~%f %F{red}❯%f '

autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%b '

setopt PROMPT_SUBST
PROMPT='%F{#6d6d86}%*%f %F{#ffa600}%~%f %F{#61b8ff}${vcs_info_msg_0_}%f%F{#FF0469}❯%f '
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

alias ls="eza --icons=always"

# ---- Zoxide (better cd) Opacity/Bac
eval "$(zoxide init zsh)"
alias cd="z"
alias bat="batcat"
