# one-time setup and tool integrations

# setup - bat
if [ ! -d "$HOME/.cache/bat" ] && alias cat | grep 'bat' >/dev/null; then
  cat cache --build 2>/dev/null
fi

# setup - fast node manager (fnm)
if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd --log-level=quiet)"
fi

# setup - atmos completion: loaded by compinit from the packaged _atmos in
# fpath. don't call `atmos completion zsh` here; every atmos run sends
# telemetry over the network and stalls shell startup
