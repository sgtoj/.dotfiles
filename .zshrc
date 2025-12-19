# profiler start (enable via ZSH_PROFILE=1)
if [[ -n $ZSH_PROFILE ]]; then
  zmodload zsh/zprof             # start profiler early
fi

export EDITOR=nvim
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_CONFIG_HOME=${HOME}/.config
export XDG_DATA_HOME=${HOME}/.local/share
export PATH=/opt/nvim/bin:${HOME}/.local/bin:${HOME}/go/bin:${HOME}/.arkade/bin/:${PATH}

export BAT_THEME="Catppuccin Mocha"
export FZF_DEFAULT_OPTS=" \
--color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
--color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
--color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
--color=selected-bg:#45475a \
--multi"

eval "$(curl -sSfL https://raw.githubusercontent.com/junegunn/fzf/master/shell/completion.zsh)"
eval "$(zoxide init --cmd cd zsh)"

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# zinit - load
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [ ! -d "${ZINIT_HOME}" ]; then
  mkdir -p "$(dirname ${ZINIT_HOME})"
  git clone https://github.com/zdharma-continuum/zinit.git "${ZINIT_HOME}"
fi
source "${ZINIT_HOME}/zinit.zsh"

# zinit - plugins
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting
zinit ice wait lucid
zinit light zsh-users/zsh-completions
zinit ice wait lucid
zinit light Aloxaf/fzf-tab

# zinit - snippets
zinit ice wait lucid snippet
zinit snippet OMZL::git.zsh
zinit ice wait lucid snippet
zinit snippet OMZP::git
zinit ice wait lucid snippet
zinit snippet OMZP::kubectl
zinit ice wait lucid snippet
zinit snippet OMZP::kubectx
zinit ice wait lucid snippet
zinit snippet OMZP::command-not-found

# zinit - load completions
autoload -Uz compinit
COMPDUMP="${XDG_CACHE_HOME:-${HOME}/.cache}/.zcompdump"
compinit -C -d "${COMPDUMP}"
zinit cdreplay -q

# zinit - customize completions
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -200'
zstyle ':fzf-tab:complete:nvim:*' fzf-preview 'bat --style=numbers --color=always --line-range :500 $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'tree -C $realpath | head -200'

# history
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
unsetopt hist_save_by_copy

# aliases
alias cat="$(command -v bat >/dev/null 2>&1 && echo 'bat -n --paging=never' || (command -v batcat >/dev/null 2>&1 && echo 'batcat -n --paging=never' || echo cat))"
alias ls="ls --color"
alias vim='nvim'

# setup - bat
if [ ! -d "$HOME/.cache/bat" ] && alias cat | grep 'bat' >/dev/null; then
  cat cache --build 2>/dev/null
fi

# setup - fast node manager (fnm)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

# keybindings (vim)
export KEYTIMEOUT=30 # 100 units is 1s
bindkey -v
bindkey -M viins 'jk'  vi-cmd-mode
bindkey -M viins '^?'  backward-delete-char   # backspace (DEL)
bindkey -M viins '^H'  backward-delete-char   # backspace (Ctrl-H)
bindkey -M viins '^f'  autosuggest-accept
bindkey -M viins '^p'  history-search-backward
bindkey -M viins '^n'  history-search-forward
bindkey -M viins '^[w' kill-region

# cursor
function zle-keymap-select {
  case $KEYMAP in
    vicmd) echo -ne '\e[1 q' ;;  # block cursor
    viins) echo -ne '\e[5 q' ;;  # beam cursor
    main)  echo -ne '\e[5 q' ;;  # fallback
  esac
}
function zle-line-init {
  echo -ne '\e[5 q'  # start with beam
}
function zle-line-finish {
  echo -ne '\e[5 q'  # reset to beam on finish
}
zle -N zle-keymap-select
zle -N zle-line-init
zle -N zle-line-finish
unset zle_bracketed_paste # disable bracketed paste messiness

# starship
eval "$(starship init zsh)"

# environment variables
export TELEPORT_TOOLS_VERSION=off
export SHELLCHECK_OPTS='-S warning'

# profiler end (enable via ZSH_PROFILE=1)
if [[ -n $ZSH_PROFILE ]]; then
  # dump stats to a file then print a one-liner summary
  zprof >${XDG_CACHE_HOME:-$HOME/.cache}/zsh_profile.txt
  printf '%s\n' 'zsh profile written to ~/.cache/zsh_profile.txt'
fi
