# environment variables and PATH

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
--border=rounded \
--multi"

export TELEPORT_TOOLS_VERSION=off
export SHELLCHECK_OPTS='-S warning'

# Keep internal MCP endpoints outside the shared dotfiles configuration.
[[ -z ${OPENCODE_CONFIG:-} && -f "${HOME}/.secrets/opencode/opencode.private.json" ]] &&
  export OPENCODE_CONFIG="${HOME}/.secrets/opencode/opencode.private.json"
