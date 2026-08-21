# Global Agent Instructions

When making changes in a Git repository, create a dedicated worktree before
editing. Run `wt` from the repository's main checkout or an existing worktree:

```sh
wt new --no-tmux <branch-name>
```

Use `--no-tmux` for agent work so the worktree can run in the background
without creating a tmux session.
