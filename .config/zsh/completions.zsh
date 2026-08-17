# completion loading and styling

autoload -Uz compinit
COMPDUMP="${XDG_CACHE_HOME:-${HOME}/.cache}/.zcompdump"
compinit -C -d "${COMPDUMP}"
zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -200'
zstyle ':fzf-tab:complete:nvim:*' fzf-preview 'bat --style=numbers --color=always --line-range :500 $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'tree -C $realpath | head -200'
