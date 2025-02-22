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
eval "$(starship init zsh)"
eval "$(zoxide init --cmd cd zsh)"

if [[ -f "/opt/homebrew/bin/brew" ]] then
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
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# zinit - snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::kubectl
zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

# zinit - load completions
autoload -Uz compinit && compinit
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

# setup - node version manager (nvm)
NVM_INSTALL_PATH=$(brew --prefix nvm 2>/dev/null || echo "0")
if [[ "${NVM_INSTALL_PATH}" != "0" ]]; then
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_INSTALL_PATH/nvm.sh" ] && . "$NVM_INSTALL_PATH/nvm.sh"  # loads nvm
  [ -s "$NVM_INSTALL_PATH/etc/bash_completion.d/nvm" ] && . "$NVM_INSTALL_PATH/etc/bash_completion.d/nvm"  # loads nvm bash_completion
fi

# keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region
