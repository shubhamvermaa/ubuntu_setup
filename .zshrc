# ==========================================
# 1. ENVIRONMENT & PATHS
# ==========================================
export PATH="$HOME/Library/Python/3.9/bin:/home/shubhamverma/.opencode/bin:$PATH"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export EDITOR="nvim"
export VISUAL="nvim"
# ==========================================
# 2. HISTORY BEHAVIOR
# ==========================================
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify
stty -ixon
# ==========================================
# 3. COMPLETION ENGINE (MUST BE BEFORE PLUGINS)
# ==========================================
autoload -Uz compinit && compinit

# ==========================================
# 4. PROMPT & VERSION CONTROL
# ==========================================
autoload -Uz vcs_info
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%b '

setopt PROMPT_SUBST
PROMPT='%F{#6d6d86}%*%f %F{#ffa600}%~%f %F{#61b8ff}${vcs_info_msg_0_}%f%F{#FF0469}❯%f '

# ==========================================
# 5. KEYBINDINGS
# ==========================================
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# ==========================================
# 6. ALIASES & EXTERNAL TOOLS
# ==========================================
alias ls="eza --icons=always"
alias bat="batcat"

eval "$(zoxide init zsh)"
alias cd="z"

# ==========================================
# 7. PLUGINS (ORDER IS CRITICAL)
# ==========================================
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-fzf-tab/fzf-tab.plugin.zsh

# Syntax highlighting MUST be the absolute last plugin loaded
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# ==========================================
# 8. PLUGIN CONFIGURATION
# ==========================================
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons --color=always $realpath'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --color=always --oneline -50 $word'

# ==========================================
# 9. CUSTOM FUNCTIONS
# ==========================================
export PATH=~/.npm-global/bin:$PATH


# Added by Antigravity CLI installer
export PATH="/home/shubhamverma/.local/bin:$PATH"
export PATH="/home/shubhamverma/.local/bin:$PATH"
export PATH="/home/shubhamverma/.local/bin:$PATH"
