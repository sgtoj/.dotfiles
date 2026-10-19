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
    ;;
  list-windows)
    printf '@1|\n@2|\n@3|\n@4|done\n'
    ;;
  set-option)
    printf '%s\n' "$*" >>"$TMUX_LOG"
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

printf '%s\n' 'oc-notify tests passed'
