#!/usr/bin/env bash

# ------------------------------------------------------------ configuration ---

APT_PACKAGES=(
  zsh
)

ARKADE_SYSTEM_PACKAGES=(
)

ARKADE_TOOL_PACKAGES=(
  k9s
  kubectl
  kubeseal
  kustomize
)

BREW_PACKAGES=(
  awscli
  bash
  bat
  eza
  deno
  fd
  ffmpeg
  fzf
  git
  gh
  go
  htop
  imagemagick
  jq
  lazygit
  neovim
  nvm
  poppler
  ripgrep
  starship
  stow
  sevenzip
  tmux
  tree
  tree-sitter
  yazi
  zoxide
)

BREW_CASK_PACKAGES=(
  1password-cli
  docker
  font-hack-nerd-font
  font-symbols-only-nerd-font
  ghostty
  git-credential-manager
  nikitabobko/tap/aerospace
)

DIRECTORIES_TO_CREATE=(
  "$HOME/repos/cs"
  "$HOME/repos/mpz"
  "$HOME/repos/pp"
  "$HOME/repos/sgtoj"
)

DOTFILES_GIT_PATH="https://github.com/sgtoj/.dotfiles"

SSH_KEY_NAME_GITHUB="git"

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
if ! command -v brew &> /dev/null; then
  log "installing homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $? -ne 0 ]]; then
    log_error "failed to install homebrew"
    exit 1
  fi
  echo >> "$HOME/.zprofile"
  echo "eval \"\$($BREW_PREFIX/bin/brew shellenv)\"" >> "$HOME/.zprofile"
else
  log "homebrew already installed"
fi
eval "$($BREW_PREFIX/bin/brew shellenv)"

# ensure homebrew is up to date
log "updating homebrew"
brew update

# install essential packages
for package in "${BREW_PACKAGES[@]}"; do
  if ! brew list "$package" &> /dev/null; then
    log "installing $package"
    brew install "$package"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $package"
      exit 1
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
  if ! brew list --cask "$cask" &> /dev/null; then
    log "installing $cask"
    brew install --cask "$cask"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $cask"
      exit 1
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
  if ! command -v $package &> /dev/null; then
    log "installing $package"
    sudo apt install "$package"
    if [[ $? -ne 0 ]]; then
      log_error "failed to install $package"
      exit 1
    fi
  else
    log "$package is already installed"
  fi
done

# install arkade
if ! command -v arkade &> /dev/null; then
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
    exit 1
  fi
  log "arkade system package $arkade_package installed"
done

# install arkade tool packages
for arkade_package in "${ARKADE_TOOL_PACKAGES[@]}"; do
  log "installing arkade package $arkade_package"
  arkade get "$arkade_package"
  if [[ $? -ne 0 ]]; then
    log_error "failed to install arkade tool package $arkade_package"
    exit 1
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
      exit 1
    fi
  else
    log "directory $dir already exists"
  fi
done

# clone dotfiles repo and run stow
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

log "running stow on dotfiles"
pushd "$DOTFILES_DIR" > /dev/null
stow .
if [[ $? -ne 0 ]]; then
  log_error "failed to run stow on dotfiles"
  popd > /dev/null
  exit 1
fi
popd > /dev/null

# install latest node lts using nvm and set as default
NVM_INSTALL_PATH=$(brew --prefix nvm)
export NVM_DIR="$HOME/.nvm"
source "$NVM_INSTALL_PATH/nvm.sh"
if command -v nvm &> /dev/null; then
  log "installing latest node lts using nvm"
  nvm install --lts
  if [[ $? -ne 0 ]]; then
    log_error "failed to install latest node lts"
    exit 1
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

if ! grep -q "Host github.com" "$SSH_CONFIG"; then
  log "configuring github.com key in ~/.ssh/config"
  {
    echo "Host github.com"
    echo "  HostName github.com"
    echo "  User git"
    echo "  IdentityFile ~/.ssh/$SSH_KEY_NAME_GITHUB"
  } >> "$SSH_CONFIG"
else
  log "github.com configuration already exists in ~/.ssh/config"
fi

# set zsh as the default shell
if [[ "$SHELL" != "/bin/zsh" ]]; then
  log "changing default shell to zsh"
  chsh -s /bin/zsh
fi

# set path to ghostty configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
  mkdir -p $HOME/Library/Application\ Support/com.mitchellh.ghostty
  echo "config-file = $HOME/.config/ghostty/config" > $HOME/Library/Application\ Support/com.mitchellh.ghostty/config
fi

log "provisioning complete"
