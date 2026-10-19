# completion loading and styling

autoload -Uz compinit
COMPDUMP="${XDG_CACHE_HOME:-${HOME}/.cache}/.zcompdump"
# -C trusts the cached dump and never sees newly installed completions, so
# rescan fpath once a day and touch the dump to restart the clock
stale_compdump=(${COMPDUMP}(N.mh+24))
if (( ${#stale_compdump} )); then
  compinit -d "${COMPDUMP}" && touch "${COMPDUMP}"
else
  compinit -C -d "${COMPDUMP}"
fi
unset stale_compdump
zinit cdreplay -q

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# wt (git worktree helper) completion
function _wt() {
  local -a subcmds
  subcmds=(
    'new:create worktree (+links +tmux session)'
    'ls:list worktrees for the current repo'
    'rm:remove worktree'
    'link:(re)inject symlinks into the current worktree'
    'gc:kill orphaned tmux sessions + prune worktrees'
  )
  if ((CURRENT == 2)); then
    _describe 'wt command' subcmds
  elif ((CURRENT == 3)); then
    case "${words[2]}" in
      new)
        local -a branches
        branches=(${(f)"$(git branch --format='%(refname:short)' 2>/dev/null)"})
        _describe 'branch' branches
        ;;
      rm)
        local root
        root=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
        if [[ -n $root && -d ${root:h}/.worktrees ]]; then
          local -a wts
          wts=(${root:h}/.worktrees/*(N:t))
          _describe 'worktree' wts
        fi
        ;;
    esac
  fi
}
compdef _wt wt
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'tree -C $realpath | head -200'
zstyle ':fzf-tab:complete:nvim:*' fzf-preview 'bat --style=numbers --color=always --line-range :500 $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'tree -C $realpath | head -200'
