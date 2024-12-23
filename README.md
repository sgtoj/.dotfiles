# .dotfiles

A personal collection of configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Usage

### Installation

1. **Clone the Repository**

    ```bash
    git clone https://github.com/sgtoj/.dotfiles.git ~/.dotfiles
    ```

2. **Navigate to the Dotfiles Directory**

    ```bash
    cd ~/.dotfiles
    ```

3. **Use GNU Stow to Symlink Configurations**

    ```bash
    stow .
    ```

### Usage

- **Updating Dotfiles**

    ```bash
    cd ~/.dotfiles
    git pull
    stow --adopt [package]
    ```

- **Removing a Configuration**

    ```bash
    stow -D [package]
    ```

--------------------------------------------------------------------------------

## MacOS Provisioning Script

The `./.local/bin/provision.sh` script provisions a new MacBook with essential
tools and configurations terminal centric workflow and development. It is
designed to be **idempotent**, meaning it is safe to run multiple times.

## Instructions

1. Run the script directly from your terminal using:

    ```bash
    sudo -v && curl -fsSL https://raw.githubusercontent.com/sgtoj/.dotfiles/main/.local/bin/provision.sh | bash
    ```

2. Save SSH keys in 1Password to `~/.ssh`

3. Open WezTerm and signin to 1Password CLI and GitHub CLI

    ```
    eval $(op signin)
    op vault list
    gh auth login
    ```

4. Import AWS CLI Config and GPG Keys from 1Password

    ```
    op-aws pull
    op-gpg pull
    ```

5. Open `nvim` and install LSPs using `:MasonInstallAll`

