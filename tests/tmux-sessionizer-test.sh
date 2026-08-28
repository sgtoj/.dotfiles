#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sessionizer="$repo_root/.local/bin/tmux-sessionizer"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
bin="$tmp/bin"
mkdir -p "$home/.dotfiles" "$bin"

cat >"$bin/tmux" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$bin/fzf" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --help ]]; then
  case ${FZF_PROFILE:-legacy} in
  modern) printf '%s\n' '--sync --track --listen=SOCKET_PATH' ;;
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

# A legacy distro fzf must still open with directories on a fresh cache.
HOME="$home" XDG_CACHE_HOME="$tmp/legacy-cache" PATH="$bin:$PATH" FZF_LOG="$log" FZF_INPUT="$input" FZF_PROFILE=legacy \
  "$sessionizer"
grep -qx "$home/.dotfiles" "$input"
grep -q -- '--listen' "$log" && {
  printf '%s\n' 'legacy fzf unexpectedly received --listen' >&2
  exit 1
}

: >"$log"
HOME="$home" XDG_CACHE_HOME="$tmp/modern-cache" PATH="$bin:$PATH" FZF_LOG="$log" FZF_INPUT="$input" FZF_PROFILE=modern \
  "$sessionizer"
[[ -s "$tmp/modern-cache/tmux-sessionizer/directories" ]]
grep -qx "$home/.dotfiles" "$input"
grep -q -- '--listen=' "$log"

printf '%s\n' 'tmux-sessionizer tests passed'
