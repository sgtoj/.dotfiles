# Global Agent Instructions

Consider using a dedicated worktree before editing; it is optional for changes
within the repository containing the current working directory.

Create a dedicated worktree when making changes in a repository other than the
current working directory's repository, or when making changes across multiple
repositories while the current working directory is outside a single repository.
Run `wt` from the repository's main checkout or an existing worktree:

```sh
wt new --no-tmux <branch-name>
```

Use `--no-tmux` for agent work so the worktree can run in the background
without creating a tmux session.
