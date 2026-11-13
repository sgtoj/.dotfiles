# .dotfiles

A personal collection of dotfiles (i.e., configuration files) managed with
[GNU Stow](https://www.gnu.org/software/stow/). Reference
[dotfiles.github.io](https://dotfiles.github.io) or this
[youtube video](https://www.youtube.com/watch?v=y6XCebnB9gs) to learn more about
dotfiles.

## Usage

Run every `stow` command from `~/.dotfiles`. The [`.stowrc`](./.stowrc) there
turns on `--no-folding`, so stow links individual files and never turns a
directory such as `~/.config` or `~/.claude` into a link into this repo. Apps
can then write their own state and credentials next to the links without landing
in the repo.

### Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/sgtoj/.dotfiles.git ~/.dotfiles
   ```

2. **Navigate to the Dotfiles Directory**

   ```bash
   cd ~/.dotfiles
   ```

3. **Enable the Secret-Scanning Git Hooks**

   ```bash
   brew install gitleaks
   git config core.hooksPath .githooks
   ```

4. **Use GNU Stow to Symlink Configurations**

   ```bash
   stow .
   ```

### Usage

- **Updating Dotfiles**

  ```bash
  cd ~/.dotfiles
  git pull
  stow -R .
  ```

- **Removing the Configurations**

  ```bash
  cd ~/.dotfiles
  stow -D .
  ```

### Secrets

This repo is public. Nothing private belongs in it.

- The `pre-commit` and `pre-push` hooks in [`.githooks`](./.githooks) run
  [gitleaks](https://github.com/gitleaks/gitleaks) and refuse to commit or push
  when it finds a secret or when gitleaks is missing. GitHub secret scanning and
  push protection are also enabled on the repository.
- [`.gitignore`](./.gitignore) ignores common credential files and directories
  anywhere in the tree.
- Keep machine-specific or private settings in untracked files:
  `~/.config/zsh/local.zsh`, `~/.config/git/local.gitconfig`, and `~/.secrets`.

______________________________________________________________________

## MacOS (and Linux) Provisioning Script

The [`./.local/bin/provision.sh`](./.local/bin/provision.sh) script provisions a
new MacBook with essential tools and configurations for a terminal centric
workflow and development. It is designed to be **idempotent**, meaning it is
safe to run multiple times.

Homebrew packages are listed in the [`Brewfile`](./Brewfile). Casks only install
on MacOS.

_This script was originally designed to run on MacOS, but works on debian or
ubuntu too. It has been used on (WSL) Ubuntu 24. Setting `zsh` as the default
shell must be done manually on Linux since `chsh` does not work from script._

### Instructions

1. Run the script directly from your terminal using:

   ```bash
   sudo -v && curl -fsSL https://raw.githubusercontent.com/sgtoj/.dotfiles/main/.local/bin/provision.sh | bash
   ```

   Existing files that would block stow are moved aside with a
   `.bak.<timestamp>` suffix.

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
