#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
adapter="$repo_root/.claude/hooks/tmux-notify"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
log="$tmp/notify.log"
mkdir -p "$home/.dotfiles/.local/bin"

cat >"$home/.dotfiles/.local/bin/oc-notify" <<'EOF'
#!/usr/bin/env bash
(IFS='|'; printf '%s\n' "$*") >>"$NOTIFY_LOG"
EOF
chmod +x "$home/.dotfiles/.local/bin/oc-notify"

hook() {
  : >"$log"
  HOME="$home" TMUX=/tmp/tmux-test,1,0 TMUX_PANE=%7 CLAUDE_PROJECT_DIR=/work/demo NOTIFY_LOG="$log" \
    "$adapter" <<<"$1"
}

expect() {
  local want="$1" got
  got=$(cat "$log")
  [[ $got == "$want" ]] || {
    printf 'expected: %s\n     got: %s\n' "$want" "$got" >&2
    exit 1
  }
}

hook '{"hook_event_name":"Stop","last_assistant_message":"All done."}'
expect 'set|%7|done|demo||done'

hook '{"hook_event_name":"StopFailure","error":"rate_limit","error_details":"429","last_assistant_message":"API Error: Rate limit reached"}'
expect 'set|%7|error|demo|API Error: Rate limit reached|error'

hook '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"npm test","description":"Run   test\nsuite"}}'
expect 'set|%7|waiting|demo|Bash: Run test suite|permission'

hook '{"hook_event_name":"PermissionRequest","tool_name":"AskUserQuestion","tool_input":{"questions":[{"question":"Which framework?"}]}}'
expect 'set|%7|waiting|demo|Which framework?|question'

hook '{"hook_event_name":"PermissionRequest","tool_name":"ExitPlanMode","tool_input":{"plan":"# Plan"}}'
expect 'set|%7|waiting|demo|plan ready for review|question'

hook '{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"Claude needs your permission"}'
expect 'set|%7|waiting|demo|Claude needs your permission|permission'

# Claude's Stop hook skips user interrupts, so the idle prompt ends a turn.
hook '{"hook_event_name":"Notification","notification_type":"idle_prompt","message":"Claude is waiting"}'
expect 'idle|%7'

hook '{"hook_event_name":"SessionStart","transcript_path":"/t/s.jsonl"}'
expect $'reset|%7\ntranscript|%7|/t/s.jsonl'

hook '{"hook_event_name":"SessionStart"}'
expect 'reset|%7'

hook '{"hook_event_name":"UserPromptSubmit","transcript_path":"/t/s.jsonl","prompt":"go"}'
expect $'transcript|%7|/t/s.jsonl\nbusy|%7'

hook '{"hook_event_name":"SessionEnd"}'
expect 'reset|%7'

# Claude sessions outside tmux must not touch any pane.
: >"$log"
env -u TMUX -u TMUX_PANE HOME="$home" NOTIFY_LOG="$log" "$adapter" <<<'{"hook_event_name":"Stop"}'
expect ''

printf '%s\n' 'claude tmux-notify tests passed'
