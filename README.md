# .dotfiles

A personal collection of dotfiles (i.e., configuration files) managed with [GNU
Stow](https://www.gnu.org/software/stow/). Reference [dotfiles.github.io](https://dotfiles.github.io)
or this [youtube video](https://www.youtube.com/watch?v=y6XCebnB9gs) to learn
more about dotfiles.

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

## MacOS (and Linux) Provisioning Script

The [`./.local/bin/provision.sh`](./.local/bin/provision.sh) script provisions a
new MacBook with essential tools and configurations terminal centric workflow
and development. It is designed to be **idempotent**, meaning it is safe to run
multiple times.

_This script was originally designed to run on MacOS, but works on debian or
ubuntu too. It has been used on (WSL) Ubuntu 24. However, none of the `brew`
casts are supported, so uses `apt` as an alternative. Finally, setting `zsh` as
the default shell must be done manually since `chsh` does not work from script._

### Instructions

1. Run the script directly from your terminal using:

    ```bash
    sudo -v && curl -fsSL https://raw.githubusercontent.com/sgtoj/.dotfiles/main/.local/bin/provision.sh | bash
    ```

2. Save SSH keys in 1Password to `~/.ssh`

3. Open a terminal (Ghostty) and signin to 1Password CLI and GitHub CLI

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

6. Change shell to `zsh` if Linux.

    ```
    chsh -s /bin/zsh
    ```
g
