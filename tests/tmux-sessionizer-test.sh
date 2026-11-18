#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sessionizer="$repo_root/.local/bin/tmux-sessionizer"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$home/.dotfiles" "$home/repos/sgtoj/web" "$home/repos/sgtoj/api" "$home/repos/sgtoj/docs" "$bin"

cat >"$bin/tmux" <<'EOF'
#!/usr/bin/env bash
case ${1:-} in
list-panes)
  if [[ $* == *'#{pane_id}'* ]]; then
    [[ -n ${TMUX_AGENTS_FILE:-} ]] && cat "$TMUX_AGENTS_FILE"
  else
    [[ -n ${TMUX_PANES_FILE:-} ]] && cat "$TMUX_PANES_FILE"
  fi
  ;;
display-message)
  if [[ $* == *pane_id* ]]; then
    printf '%s\n' "${TMUX_CURRENT_PANE:-}"
  else
    printf '%s\n' "${TMUX_CURRENT:-}"
  fi
  ;;
esac
exit 0
EOF

cat >"$bin/fzf" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --help ]]; then
  case ${FZF_PROFILE:-legacy} in
  modern) printf '%s\n' '--footer --sync --track --no-input' ;;
  *) printf '%s\n' 'legacy fzf' ;;
  esac
  exit 0
fi
printf '%s\n' "$*" >>"$FZF_LOG"
cat >"$FZF_INPUT"
exit 1
EOF
chmod +x "$bin/tmux" "$bin/fzf"

log="$tmp/fzf.log"
input="$tmp/fzf-input"
path="$bin:/usr/bin:/bin"

# A legacy distro fzf must still open with directories on a fresh cache, as a
# plain search-only picker.
HOME="$home" XDG_CACHE_HOME="$tmp/legacy-cache" PATH="$path" FZF_LOG="$log" FZF_INPUT="$input" FZF_PROFILE=legacy \
  "$sessionizer"
cut -f5 "$input" | grep -qx "$home/.dotfiles"
for option in --footer --no-input; do
  grep -q -- "$option" "$log" && {
    printf 'legacy fzf unexpectedly received %s\n' "$option" >&2
    exit 1
  }
done

# The full picker opens for browsing (j/k, / to search) and keeps open sessions
# above projects while searching.
: >"$log"
HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$path" FZF_LOG="$log" FZF_INPUT="$input" FZF_PROFILE=modern \
  "$sessionizer"
[[ -s "$tmp/modern-cache/tmux-sessionizer/projects" ]]
cut -f5 "$input" | grep -qx "$home/.dotfiles"
grep -q -- '--footer=' "$log"
grep -q -- '--no-input' "$log"
grep -q -- '--bind=j:down' "$log"
grep -q -- '--no-sort' "$log"
grep -q -- 'j/k move · / search' "$log"

# Sessions sort by agent urgency, then label. The current session is hidden,
# a flag on a pane whose agent exited is ignored, and project directories that
# already have a session are left out.
us=$'\x1f'
panes="$tmp/panes"
{
  printf '%s\n' "current${us}$home/repos/sgtoj/web${us}1${us}1${us}1${us}${us}zsh"
  printf '%s\n' "idle${us}$home/.dotfiles${us}1${us}1${us}1${us}${us}nvim"
  printf '%s\n' "finished${us}$home/repos/sgtoj/api${us}2${us}1${us}1${us}done${us}2.1.300"
  printf '%s\n' "finished${us}$home/repos/sgtoj/api${us}2${us}0${us}1${us}${us}zsh"
  printf '%s\n' "blocked${us}/tmp${us}1${us}1${us}1${us}waiting${us}opencode"
  printf '%s\n' "stale${us}/tmp${us}1${us}1${us}1${us}waiting${us}zsh"
  printf '%s\n' "busy${us}/tmp${us}1${us}1${us}1${us}${us}claude${us}1"
} >"$panes"

candidates() {
  HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$path" TMUX=test TMUX_CURRENT=current \
    TMUX_PANES_FILE="$panes" "$sessionizer" --candidates "$@"
}

sessions=$(candidates | awk -F'\t' '$4 == "session" { print $5 }' | tr '\n' ' ')
[[ $sessions == "blocked finished busy idle stale " ]] || {
  printf 'unexpected session order: %s\n' "$sessions" >&2
  exit 1
}

projects=$(candidates | awk -F'\t' '$4 == "dir" { print $5 }')
[[ $projects == "$home/repos/sgtoj/docs" ]] || {
  printf 'unexpected projects: %s\n' "$projects" >&2
  exit 1
}

picker="$tmp/picker"
mkdir -p "$picker"
printf 'attention\n' >"$picker/mode"
printf 'current\n' >"$picker/current"
attention=$(candidates "$picker" | awk -F'\t' '{ print $4 ":" $5 }' | tr '\n' ' ')
[[ $attention == "session:blocked session:finished " ]] || {
  printf 'unexpected attention rows: %s\n' "$attention" >&2
  exit 1
}

# The agents view lists agent panes, most urgent first and then most recently
# changed. The current pane, non-agent panes, and stale flags are left out, and
# an agent in a subdirectory is labeled by its repo.
agents="$tmp/agents"
{
  printf '%s\n' "%1${us}current${us}$home/repos/sgtoj/web${us}1${us}0${us}claude${us}$home/repos/sgtoj/web${us}${us}${us}400${us}${us}"
  printf '%s\n' "%2${us}api${us}$home/repos/sgtoj/api${us}1${us}0${us}2.1.300${us}$home/repos/sgtoj/api/src${us}${us}1${us}100${us}${us}"
  printf '%s\n' "%3${us}ops${us}/tmp${us}1${us}0${us}claude${us}/tmp${us}waiting${us}1${us}50${us}Bash: ls${us}"
  printf '%s\n' "%4${us}web${us}/tmp${us}2${us}0${us}opencode${us}/tmp${us}done${us}${us}300${us}${us}"
  printf '%s\n' "%5${us}web${us}/tmp${us}3${us}0${us}opencode${us}/tmp${us}done${us}${us}200${us}${us}"
  printf '%s\n' "%6${us}shell${us}/tmp${us}1${us}0${us}zsh${us}/tmp${us}waiting${us}1${us}500${us}${us}"
  printf '%s\n' "%7${us}notes${us}/tmp${us}1${us}0${us}claude${us}/tmp${us}${us}${us}10${us}${us}"
} >"$agents"

agent_rows() {
  HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$path" TMUX=test TMUX_CURRENT_PANE=%1 \
    TMUX_AGENTS_FILE="$agents" "$sessionizer" --candidates "$@"
}

printf 'agents\n' >"$picker/view"
printf '%%1\n' >"$picker/pane"
printf 'all\n' >"$picker/mode"
order=$(agent_rows "$picker" | awk -F'\t' '$4 == "agent" { print $5 }' | tr '\n' ' ')
[[ $order == "%3 %4 %5 %2 %7 " ]] || {
  printf 'unexpected agent order: %s\n' "$order" >&2
  exit 1
}
agent_rows "$picker" | awk -F'\t' '$5 == "%2" { print $6 }' | grep -qx 'claude in sgtoj/api'
agent_rows "$picker" | awk -F'\t' '$5 == "%3"' | grep -q 'Bash: ls'

printf 'attention\n' >"$picker/mode"
order=$(agent_rows "$picker" | awk -F'\t' '{ print $4 ":" $5 }' | tr '\n' ' ')
[[ $order == "agent:%3 agent:%4 agent:%5 " ]] || {
  printf 'unexpected agent attention rows: %s\n' "$order" >&2
  exit 1
}
printf 'sessions\n' >"$picker/view"

# The agents view starts browsing: no input, j/k move, / searches.
: >"$log"
HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$path" FZF_LOG="$log" FZF_INPUT="$input" FZF_PROFILE=modern \
  TMUX_AGENTS_FILE="$agents" "$sessionizer" --agents
grep -q -- '--no-input' "$log"
grep -q -- '--bind=j:down' "$log"
grep -q -- '--bind=/:transform:' "$log"
grep -q -- 'j/k move · / search' "$log"

# After every result update the cursor goes to the best match while typing,
# else to the first row under the section header.
home_for() {
  FZF_QUERY="$1" PATH="$path" "$sessionizer" --home "$picker"
}
printf 'all\n' >"$picker/mode"
[[ $(home_for "") == "pos(2)" && $(home_for doc) == "first" ]]
printf 'attention\n' >"$picker/mode"
[[ $(home_for "") == "first" && $(home_for doc) == "first" ]]
grep -q -- '--track' "$log" && {
  printf '%s\n' '--track keeps the cursor on a mid-list row while typing' >&2
  exit 1
}

# Long repo, worktree, and branch names are clipped so every row of a kind
# keeps the same column widths.
long="terraform-aws-cognito-custom-message-sender-with-a-very-long-name"
mkdir -p "$home/repos/cs/$long/.worktrees/ci-use-cruxstack-release-actions" "$home/repos/cs/$long-two"
printf '%s\n' "wide${us}$home/repos/cs/$long${us}1${us}1${us}1${us}${us}zsh" >>"$panes"
HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$path" "$sessionizer" --refresh-directories
printf 'all\n' >"$picker/mode"
widths=$(candidates "$picker" | perl -CSD -F'\t' -lane '
  next if $F[3] eq "header";
  ($name = $F[1]) =~ s/\e\[[0-9;]*m//g;
  print "$F[3] " . length($name);
' | sort -u | awk '{ print $1 }' | uniq -d)
[[ -z $widths ]] || {
  printf 'rows of these kinds have uneven name columns: %s\n' "$widths" >&2
  exit 1
}

printf '%s\n' 'tmux-sessionizer tests passed'
