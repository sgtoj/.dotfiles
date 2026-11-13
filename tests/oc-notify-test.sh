#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
notifier="$repo_root/.local/bin/oc-notify"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
log="$tmp/tmux.log"
mkdir -p "$bin"

cat >"$bin/tmux" <<'EOF'
#!/usr/bin/env bash

case "${1:-}" in
  list-panes)
    printf '%%test|done|@1|opencode\n'
    printf '%%claude|done|@2|2.1.296\n'
    printf '%%asking|waiting|@3|claude\n'
    printf '%%shell|done|@4|zsh\n'
    printf '%%gone||@5|zsh|1\n'
    ;;
  list-windows)
    printf '@1|\n@2|\n@3|\n@4|done\n'
    ;;
  set-option)
    printf '%s\n' "$*" >>"$TMUX_LOG"
    ;;
  display-message)
    case "$*" in
      *'#{pane_id}'*) printf '%%7\n' ;;
      *) printf 'work|00\n' ;;
    esac
    ;;
  show-options)
    [[ $* == *@oc_busy* ]] && printf '%s\n' "${FAKE_BUSY:-}"
    ;;
esac
EOF
chmod +x "$bin/tmux"

env -u TMUX HOME="$tmp/home" PATH="$bin:$PATH" TMUX_LOG="$log" "$notifier" refresh

grep -Fqx 'set-option -w -t @1 @oc_win done' "$log"
grep -Fq 'set-option -g @oc_alert ' "$log"
if grep -Fq 'set-option -pu -t %test @oc_state' "$log"; then
  printf '%s\n' 'released OpenCode panes must retain their marker' >&2
  exit 1
fi

# Claude's native binary is named after its version, so either name must count.
grep -Fqx 'set-option -w -t @2 @oc_win done' "$log"
grep -Fqx 'set-option -w -t @3 @oc_win waiting' "$log"
if grep -Fq 'set-option -pu -t %claude @oc_state' "$log" || grep -Fq 'set-option -pu -t %asking @oc_state' "$log"; then
  printf '%s\n' 'Claude panes must retain their marker' >&2
  exit 1
fi

# A pane whose agent exited drops its stale flag and window marker.
grep -Fqx 'set-option -pu -t %shell @oc_state' "$log"
grep -Fqx 'set-option -wu -t @4 @oc_win' "$log"

# Agents are counted together rather than per tool.
grep -F 'set-option -g @oc_alert ' "$log" | grep -Fq ' waiting 1'
grep -F 'set-option -g @oc_alert ' "$log" | grep -Fq ' done 2'

# A working mark left on a pane whose agent exited is dropped too.
grep -Fqx 'set-option -pu -t %gone @oc_busy' "$log"

notify() {
  : >"$log"
  env -u TMUX HOME="$tmp/home" PATH="$bin:$PATH" TMUX_LOG="$log" "$notifier" "$@"
}

refute() {
  if grep -Fq -- "$1" "$log"; then
    printf 'unexpected: %s\n' "$1" >&2
    exit 1
  fi
}

# A submitted prompt marks the pane working and stamps when it started.
notify busy %7
grep -Fqx 'set-option -p -t %7 @oc_busy 1' "$log"
grep -Fq 'set-option -p -t %7 @oc_since ' "$log"

# A finished turn ends the working mark; a question in the middle of one does not.
FAKE_BUSY=1 notify set %7 'done' demo
grep -Fqx 'set-option -pu -t %7 @oc_busy' "$log"
grep -Fqx 'set-option -p -t %7 @oc_state done' "$log"

FAKE_BUSY=1 notify set %7 waiting demo 'Bash: ls'
refute 'set-option -pu -t %7 @oc_busy'
grep -Fqx 'set-option -p -t %7 @oc_detail Bash: ls' "$log"

# An interrupted turn goes idle; an idle pane is left alone.
FAKE_BUSY=1 notify idle %7
grep -Fqx 'set-option -pu -t %7 @oc_busy' "$log"
grep -Fq 'set-option -p -t %7 @oc_since ' "$log"
notify idle %7
refute '@oc_busy'
refute '@oc_since'

# A started or exited agent forgets its turn and transcript.
notify reset %7
grep -Fqx 'set-option -pu -t %7 @oc_busy' "$log"
grep -Fqx 'set-option -pu -t %7 @oc_transcript' "$log"

notify transcript %7 /t/s.jsonl
grep -Fqx 'set-option -p -t %7 @oc_transcript /t/s.jsonl' "$log"

printf '%s\n' 'oc-notify tests passed'
