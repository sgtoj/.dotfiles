# plugin managers and plugins (zoxide, brew, zinit)

eval "$(zoxide init --cmd cd zsh)"

if [[ -f "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  source "/opt/homebrew/opt/fzf/shell/completion.zsh"
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
