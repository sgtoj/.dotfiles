#!/usr/bin/env bash

# -------------------------------------------------------------- description ---

# an idempotent script to quickly provision a personalized development
# environment by installing essential packages and tools with configurations
#
# features:
# - works on macos and debian/ubuntu linux
# - installs packages using brew (Brewfile), apt, arkade, and uv
# - creates directories for organizing workspaces
# - clones and applies dotfiles using stow
# - enables the dotfiles secret-scanning git hooks
# - sets up ssh for github access
# - configures node.js via fnm
# - switches the default shell to zsh

# ------------------------------------------------------------ configuration ---

# all configuration options are centralized in this section below for easy and
# quick modification; homebrew packages live in the dotfiles Brewfile

# linux only packages
APT_PACKAGES=(
  bind9-dnsutils # utilities (dig, nslookup, etc)
  clang          # dev tool
  make           # dev tool
  xclip          # clipboard - fixes copy/paste wsl issues
  zsh            # terminal shell
)

# macos and linux binaries - https://github.com/alexellis/arkade
ARKADE_TOOL_PACKAGES=(
  helm        # dev tool
  k9s         # terminal ui for k8s
  kubeconform # dev tool
  kubectl     # dev tool
  kubeseal    # dev tool
  kustomize   # dev tool
  terraform   # dev tool
  tilt        # dev tool
)

# linux only binaries - macos installs these from the Brewfile
ARKADE_LINUX_TOOL_PACKAGES=(
  op # 1password cli
)

# ai tools installed with provider's script
AI_TOOLS=(
  claudecode
  codex
  opencode
)

# python tools installed with uv tool
UV_TOOLS=(
  "black"
  "mdformat --with mdformat-gfm"
)

# list of directories to ensure it exists
DIRECTORIES_TO_CREATE=(
  "$HOME/repos/cs"
  "$HOME/repos/gh"
  "$HOME/repos/mpz"
  "$HOME/repos/pp"
  "$HOME/repos/scrap"
  "$HOME/repos/sgtoj"
)

# dotfiles - https://www.youtube.com/watch?v=y6XCebnB9gs
DOTFILES_GIT_PATH="https://github.com/sgtoj/.dotfiles"
DOTFILES_DIR="$HOME/.dotfiles"

# default ssh key name for github.com (skips if empty)
SSH_KEY_NAME_GITHUB="git"

# node.js version installed with fnm and set as default
NODE_VERSION=24

# teleport binaries (brew's pkg is out of date) - https://goteleport.com/
TELEPORT_VERSION=18.6.1
TELEPORT_EDITION=oss

# ---------------------------------------------------------------------- fns ---

log() {
  echo -e "\033[1;32m[I] $1\033[0m"
}

log_error() {
  echo -e "\033[1;31m[E] $1\033[0m" >&2
}

is_macos() {
  [[ $OSTYPE == darwin* ]]
}

install_homebrew() {
  local prefix=/opt/homebrew
  is_macos || prefix=/home/linuxbrew/.linuxbrew

  if [[ -x $prefix/bin/brew ]]; then
    log "homebrew already installed"
  else
    log "installing homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
      log_error "failed to install homebrew"
      exit 1
    }
  fi
  eval "$("$prefix/bin/brew" shellenv)"

  log "updating homebrew"
  brew update
  log "upgrading existing homebrew packages"
  brew upgrade
}

clone_dotfiles() {
  if [[ -d $DOTFILES_DIR ]]; then
    log "dotfiles repo already cloned"
    return
  fi
  log "cloning dotfiles repo"
  git clone "$DOTFILES_GIT_PATH" "$DOTFILES_DIR" || {
    log_error "failed to clone dotfiles repo"
    exit 1
  }
}

install_brew_packages() {
  log "installing homebrew packages from Brewfile"
  brew bundle install --file="$DOTFILES_DIR/Brewfile" ||
    log_error "failed to install some homebrew packages"
}

install_apt_packages() {
  is_macos && return
  local package missing
  missing=()
  for package in "${APT_PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
      log "$package is already installed"
    else
      missing+=("$package")
    fi
  done
  [[ ${#missing[@]} -eq 0 ]] && return
  log "installing apt packages: ${missing[*]}"
  sudo apt-get update && sudo apt-get install -y "${missing[@]}" ||
    log_error "failed to install apt packages"
}

install_arkade_tools() {
  local tool tools
  tools=("${ARKADE_TOOL_PACKAGES[@]}")
  is_macos || tools+=("${ARKADE_LINUX_TOOL_PACKAGES[@]}")
  for tool in "${tools[@]}"; do
    log "installing arkade tool $tool"
    arkade get "$tool" || log_error "failed to install arkade tool $tool"
  done
}

install_ai_tools() {
  local tool
  for tool in "${AI_TOOLS[@]}"; do
    log "installing ai tool $tool"
    case $tool in
      claudecode) curl -fsSL https://claude.ai/install.sh | bash ;;
      codex) curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh ;;
      opencode) curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path ;;
      *) false ;;
    esac || log_error "failed to install ai tool $tool"
  done
}

install_uv_tools() {
  local uv_tool tool_name
  for uv_tool in "${UV_TOOLS[@]}"; do
    tool_name=${uv_tool%% *}
    if uv tool list 2>/dev/null | grep -q "^$tool_name "; then
      log "uv tool $tool_name already installed"
    else
      log "installing uv tool $tool_name"
      # shellcheck disable=SC2086
      uv tool install $uv_tool || log_error "failed to install uv tool $tool_name"
    fi
  done
}

create_directories() {
  local dir
  for dir in "${DIRECTORIES_TO_CREATE[@]}"; do
    if [[ -d $dir ]]; then
      log "directory $dir already exists"
    else
      log "creating directory $dir"
      mkdir -p "$dir" || log_error "failed to create directory $dir"
    fi
  done
}

stow_conflicts() {
  stow -n -R . 2>&1 | sed -n \
    -e 's/^  \* cannot stow .* over existing target \(.*\) since .*$/\1/p' \
    -e 's/^  \* existing target is not owned by stow: \(.*\)$/\1/p'
}

stow_dotfiles() {
  local suffix target
  suffix=".bak.$(date +%Y%m%d%H%M%S)"

  pushd "$DOTFILES_DIR" >/dev/null || exit 1

  while IFS= read -r target; do
    [[ -n $target ]] || continue
    log "moving existing ~/$target to ~/$target$suffix"
    mv "$HOME/$target" "$HOME/$target$suffix" || {
      log_error "could not move ~/$target"
      exit 1
    }
  done < <(stow_conflicts)

  log "running stow on dotfiles"
  stow -R . || {
    log_error "failed to run stow on dotfiles"
    exit 1
  }

  popd >/dev/null || exit 1
}

enable_git_hooks() {
  log "enabling dotfiles git hooks"
  git -C "$DOTFILES_DIR" config core.hooksPath .githooks
}

install_node() {
  if ! command -v fnm >/dev/null 2>&1; then
    log_error "fnm is not installed"
    return
  fi
  eval "$(fnm env)"
  log "installing node v$NODE_VERSION using fnm"
  fnm install "$NODE_VERSION" || log_error "failed to install node v$NODE_VERSION"
  log "setting node v$NODE_VERSION as default"
  fnm default "$NODE_VERSION"
}

configure_ssh() {
  local ssh_config="$HOME/.ssh/config"

  if [[ ! -d $HOME/.ssh ]]; then
    log "creating ~/.ssh directory"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
  fi

  if [[ ! -f $ssh_config ]]; then
    log "creating ~/.ssh/config"
    touch "$ssh_config"
    chmod 600 "$ssh_config"
  fi

  [[ -n $SSH_KEY_NAME_GITHUB ]] || return
  if grep -q "Host github.com" "$ssh_config"; then
    log "github.com configuration already exists in ~/.ssh/config"
    return
  fi
  log "configuring github.com key in ~/.ssh/config"
  {
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile ~/.ssh/$SSH_KEY_NAME_GITHUB"
  } >>"$ssh_config"
}

install_ssm_plugin() {
  is_macos && return
  if command -v session-manager-plugin >/dev/null 2>&1; then
    log "aws session-manager plugin already installed"
    return
  fi

  local arch tmp
  case "$(dpkg --print-architecture)" in
    arm64) arch=ubuntu_arm64 ;;
    *) arch=ubuntu_64bit ;;
  esac
  tmp=$(mktemp -d)

  log "installing aws session-manager plugin"
  curl -fsSL -o "$tmp/session-manager-plugin.deb" \
    "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/$arch/session-manager-plugin.deb" &&
    sudo dpkg -i "$tmp/session-manager-plugin.deb" ||
    log_error "failed to install aws session-manager plugin"
  rm -rf "$tmp"
}

install_teleport() {
  if command -v tsh >/dev/null 2>&1; then
    log "teleport already installed"
    return
  fi

  log "installing teleport $TELEPORT_VERSION"
  if is_macos; then
    local tmp
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/teleport.pkg" "https://cdn.teleport.dev/teleport-${TELEPORT_VERSION}.pkg" &&
      sudo installer -pkg "$tmp/teleport.pkg" -target / ||
      log_error "failed to install teleport"
    rm -rf "$tmp"
  else
    curl -fsSL "https://cdn.teleport.dev/install-v${TELEPORT_VERSION}.sh" |
      bash -s "$TELEPORT_VERSION" "$TELEPORT_EDITION" ||
      log_error "failed to install teleport"
  fi
}

configure_docker_group() {
  is_macos && return
  id -nG "$USER" | grep -qw docker && return
  getent group docker >/dev/null || sudo groupadd docker
  sudo usermod -aG docker "$USER"
  log "added $USER to the docker group; log out and back in to apply it"
}

set_default_shell() {
  local zsh_path
  zsh_path=$(command -v zsh)
  if [[ $SHELL != "$zsh_path" ]]; then
    log "changing default shell to zsh at $zsh_path"
    chsh -s "$zsh_path"
  fi
}

# ------------------------------------------------------------------- script ---

main() {
  install_homebrew
  clone_dotfiles
  install_brew_packages
  install_apt_packages

  export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
  install_arkade_tools
  install_ai_tools
  install_uv_tools

  create_directories
  stow_dotfiles
  enable_git_hooks

  install_node
  configure_ssh
  install_ssm_plugin
  install_teleport
  configure_docker_group
  set_default_shell

  log "provisioning complete"
}

main "$@"
