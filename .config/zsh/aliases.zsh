# aliases

alias cat="$(command -v bat >/dev/null 2>&1 && echo 'bat -n --paging=never' || (command -v batcat >/dev/null 2>&1 && echo 'batcat -n --paging=never' || echo cat))"
alias vim='nvim'

# ls -> eza when available, plain ls otherwise
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --color=always --icons=auto'
  alias ll='eza --color=always --icons=auto -l'
  alias la='eza --color=always --icons=auto -la'
else
  alias ls='ls --color'
  alias ll='ls --color -l'
  alias la='ls --color -la'
fi
