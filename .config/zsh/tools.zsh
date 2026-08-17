# one-time setup and tool integrations

# setup - bat
if [ ! -d "$HOME/.cache/bat" ] && alias cat | grep 'bat' >/dev/null; then
  cat cache --build 2>/dev/null
fi

# setup - fast node manager (fnm)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --log-level=quiet)"
fi

# setup - atmos completion
if command -v atmos &>/dev/null; then
  source <(atmos completion zsh)
fi
