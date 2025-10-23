#!/usr/bin/env bash

# -------------------------------------------------------------- description ---

# an idempotent script to quickly provision a personalized development
# environment by installing essential packages and tools with configurations
#
# features:
# - works on macos and debian/ubuntu linux
# - installs packages and binaries using brew, apt, and arkade
# - creates directories for organizing workspaces
# - clones and applies dotfiles using stow
# - sets up ssh for github access
# - configures node.js via nvm
# - switches the default shell to zsh
# - configures ghostty on macos

# ------------------------------------------------------------ configuration ---

# all configuration options are centralized in this section below for easy and
# quick modification

# linux only packages
APT_PACKAGES=(
  bind9-dnsutils # utilities (dig, nslookup, etc)
  clang          # dev tool
  make           # dev tool
  zsh            # terminal shell
)

# macos and linux binaries - https://github.com/alexellis/arkade
ARKADE_TOOL_PACKAGES=(
  k9s       # terminal ui for k8s
  kubectl   # dev tool
  kubeseal  # dev tool
  kustomize # dev tool
  op        # 1password cli (latest)
  terraform # dev tool
  tilt      # dev tool
)

# linux only packages - https://github.com/alexellis/arkade?tab=readme-ov-file#install-system-packages
ARKADE_SYSTEM_PACKAGES=(
)

# macos and linux packages
BREW_PACKAGES=(
  awscli      # dev tool
  bash        # latest bash
  bat         # alternative to cat
  btop        # alternative to htop
  eza         # alternative to ls
  deno        # dev tool
  fd          # alternative to find
  ffmpeg      # dependency: yazi
  fzf         # tool to fuzzy find
  git         # latest git
  gh          # dev tool: github cli
  go          # dev tool
  httpie      # alternative to curl
  imagemagick # dependency: yazi
  jq          # dev tool
  lazygit     # terminal ui for git
  libgit2     # dependency: terraform
  neovim      # alternative to vim
  nvm         # dev tool: node-version-manager
  opencode    # dev tool: ai tool
  poppler     # dependency: yazi
  prettier    # dev tool for formatting
  ripgrep     # alternative to grep
  shellcheck  # dev tool: shell linting
  starship    # terminal prompt
  stow        # tool to manage dotfiles
  sevenzip    # dependency: yazi
  tmux        # terminal multiplexer
  tofu-ls     # dev tool for tf lsp
  tree        # tool to display dir
  tree-sitter # dev tool: code parsing
  yazi        # terminal file manager
  yq          # dev tool
  zoxide      # tool to navigate fs
)

# macos only packages
BREW_CASK_PACKAGES=(
  1password-cli               # 1password cli
  docker                      # dev tool
  font-hack-nerd-font         # font
  font-symbols-only-nerd-font # font
  ghostty                     # terminal
  git-credential-manager      # dev tool
  orbstack                    # alternative to docker (mac only)
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

# dotfiles (skips if empty) - https://www.youtube.com/watch?v=y6XCebnB9gs
DOTFILES_GIT_PATH="https://github.com/sgtoj/.dotfiles"

# default ssh key name for github.com (skips if empty)
SSH_KEY_NAME_GITHUB="git"

# teleport binaries (brew's pkg is out of date) - https://goteleport.com/
TELEPORT_VERSION=17.4.8
TELEPORT_EDITION=oss

# ---------------------------------------------------------------------- fns ---

log() {
  echo -e "\033[1;32m[I] $1\033[0m"
}

log_error() {
  echo -e "\033[1;31m[E] $1\033[0m" >&2
}

# ------------------------------------------------------------------- script ---

# check and install homebrew if not already installed
BREW_PREFIX=/opt/homebrew
if [[ $OSTYPE != "darwin"* ]]; then
  BREW_PREFIX=/home/linuxbrew/.linuxbrew
fi
if ! command -v brew &>/dev/null; then
  log "installing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $? -ne 0 ]]; then
    log_error "failed to install homebrew"
    exit 1
  fi
  echo >>"$HOME/.zprofile"
  echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >>"$HOME/.zprofile"
else
  log "homebrew already installed"
fi
eval "$($BREW_PREFIX/bin/brew shellenv)"

# ensure homebrew is up to date
log "updating homebrew"
brew update

# install essential packages
for package in "${BREW_PACKAGES[@]}"; do
  if ! brew list "$package" &>/dev/null; then
    log "installing $package"
    brew install "$package"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $package"
    fi
  else
    log "$package is already installed"
  fi
done

# install cask packages
for cask in "${BREW_CASK_PACKAGES[@]}"; do
  if [[ $OSTYPE != "darwin"* ]]; then
    continue
  fi
  if ! brew list --cask "$cask" &>/dev/null; then
    log "installing $cask"
    brew install --cask "$cask"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $cask"
    fi
  else
    log "$cask is already installed"
  fi
done

# install apt packages
for package in "${APT_PACKAGES[@]}"; do
  if [[ $OSTYPE == "darwin"* ]]; then
    continue
  fi
  if ! command -v "$package" &>/dev/null; then
    log "installing $package"
    sudo apt install "$package"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $package"
    fi
  else
    log "$package is already installed"
  fi
done

# install arkade
if ! command -v arkade &>/dev/null; then
  log "installing arkade"
  curl -sLS https://get.arkade.dev | sudo bash
  if [[ $? -ne 0 ]]; then
    log_error "failed to install arkade"
    exit 1
  fi
else
  log "arkade already installed"
fi

# install arkade system packages
for arkade_package in "${ARKADE_SYSTEM_PACKAGES[@]}"; do
  log "installing arkade package $arkade_package"
  arkade system install "$arkade_package"
  if [[ $? -ne 0 ]]; then
    log_error "failed to install arkade system package $arkade_package"
  fi
  log "arkade system package $arkade_package installed"
done

# install arkade tool packages
for arkade_package in "${ARKADE_TOOL_PACKAGES[@]}"; do
  log "installing arkade package $arkade_package"
  arkade get "$arkade_package"
  if [[ $? -ne 0 ]]; then
    log_error "failed to install arkade tool package $arkade_package"
  fi
  log "arkade tool package $arkade_package installed"
done

# create directories if they don't exist
for dir in "${DIRECTORIES_TO_CREATE[@]}"; do
  if [[ ! -d "$dir" ]]; then
    log "creating directory $dir"
    mkdir -p "$dir"
    if [[ $? -ne 0 ]]; then
      log_error "failed to create directory $dir"
    fi
  else
    log "directory $dir already exists"
  fi
done

# clone dotfiles repo and run stow
if [ -n "$DOTFILES_GIT_PATH" ]; then
  DOTFILES_DIR="$HOME/.dotfiles"
  if [[ ! -d "$DOTFILES_DIR" ]]; then
    log "cloning dotfiles repo"
    git clone "$DOTFILES_GIT_PATH" "$DOTFILES_DIR"
    if [[ $? -ne 0 ]]; then
      log_error "failed to clone dotfiles repo"
      exit 1
    fi
  else
    log "dotfiles repo already cloned"
  fi

  pushd "$DOTFILES_DIR" >/dev/null || exit

  log "preparing to symlink dotfiles"
  mapfile -t STOW_LINKS < <(stow . -n -v 2>/dev/null | grep '^LINK:' | sed -n 's/^LINK: \(.*\) =>.*$/\1/p')

  for target in "${STOW_LINKS[@]}"; do
    # skip if deeper than 1 level (slash in $target)
    if [[ "$target" == */* ]]; then
      continue
    fi

    target_path="$HOME/$target"
    if [[ -e "$target_path" ]]; then
      log "renaming $target_path to $target_path.bak"
      mv "$target_path" "$target_path.bak"
      if [[ $? -ne 0 ]]; then
        log_error "could not rename $target_path"
        popd >/dev/null || exit
        exit 1
      fi
    fi
  done

  log "running stow on dotfiles"
  stow .
  if [[ $? -ne 0 ]]; then
    log_error "failed to run stow on dotfiles"
    popd >/dev/null || exit
    exit 1
  fi
  popd >/dev/null || exit
fi

# install latest node lts using nvm and set as default
NVM_INSTALL_PATH=$(brew --prefix nvm)
export NVM_DIR="$HOME/.nvm"
source "$NVM_INSTALL_PATH/nvm.sh"
if command -v nvm &>/dev/null; then
  log "installing latest node lts using nvm"
  nvm install --lts
  if [[ $? -ne 0 ]]; then
    log_error "failed to install latest node lts"
  fi
  log "setting latest node lts as default"
  nvm alias default lts/*
else
  log_error "nvm is not installed"
fi

# ensure ~/.ssh/config exists and configure github.com key
SSH_CONFIG="$HOME/.ssh/config"
if [[ ! -d "$HOME/.ssh" ]]; then
  log "creating ~/.ssh directory"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
fi

if [[ ! -f "$SSH_CONFIG" ]]; then
  log "creating ~/.ssh/config"
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"
fi

if [ -n "$SSH_KEY_NAME_GITHUB" ]; then
  if ! grep -q "Host github.com" "$SSH_CONFIG"; then
    log "configuring github.com key in ~/.ssh/config"
    {
      echo "Host github.com"
      echo "  HostName github.com"
      echo "  User git"
      echo "  IdentityFile ~/.ssh/$SSH_KEY_NAME_GITHUB"
    } >>"$SSH_CONFIG"
  else
    log "github.com configuration already exists in ~/.ssh/config"
  fi
fi

# add aws ssm sessions plugin
if [[ ! -f "/usr/local/bin/session-manager-plugin" ]]; then
  log "installing aws session-manager plugin"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/mac/sessionmanager-bundle.zip" -o "sessionmanager-bundle.zip"
    unzip sessionmanager-bundle.zip
    sudo ./sessionmanager-bundle/install -i /usr/local/sessionmanagerplugin -b /usr/local/bin/session-manager-plugin
  else
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
    sudo dpkg -i session-manager-plugin.deb
  fi
  rm -rf sessionmanager-bundle*
  rm session-manager-*
fi

# add teleport binaries
if ! command -v tsh &>/dev/null && ! command -v tctl &>/dev/null; then
  log "installing teleport binaries"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    curl -O https://cdn.teleport.dev/teleport-${TELEPORT_VERSION}.pkg
    sudo installer -pkg teleport-${TELEPORT_VERSION}.pkg -target /
  else
    curl https://cdn.teleport.dev/install-v${TELEPORT_VERSION}.sh | bash -s ${TELEPORT_VERSION} ${TELEPORT_EDITION}
  fi
  rm teleport-*
fi

# add to docker group if linux
if [[ "$OSTYPE" != "darwin"* && ! $(groups $USER) =~ \bdocker\b ]]; then
  sudo groupadd docker
  sudo gpasswd -a $USER docker
  newgrp docker
fi

# set zsh as the default shell
if [[ "$SHELL" != "/bin/zsh" ]]; then
  log "changing default shell to zsh"
  chsh -s /bin/zsh
fi

# set path to ghostty configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
  mkdir -p "$HOME/Library/Application\ Support/com.mitchellh.ghostty"
  echo "config-file = $HOME/.config/ghostty/config" >$HOME/Library/Application\ Support/com.mitchellh.ghostty/config
fi

log "provisioning complete"
