#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
wrapper="$repo_root/.local/bin/tsh-mcp"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
state="$tmp/state"
mkdir -p "$bin"

cat >"$bin/tsh" <<'EOF'
#!/usr/bin/env bash

case "$1" in
  status)
    [[ -f $TSH_STATE/session ]]
    ;;
  login)
    printf 'login\n' >>"$TSH_STATE/calls"
    printf 'open this URL to log in\n'
    sleep "${LOGIN_DELAY:-0}"
    [[ -n ${LOGIN_FAILS:-} ]] || touch "$TSH_STATE/session"
    ;;
  mcp)
    printf 'mcp %s\n' "${*:2}" >>"$TSH_STATE/calls"
    printf 'mcp-stdout\n'
    ;;
esac
EOF
chmod +x "$bin/tsh"

reset() {
  rm -rf "$state" "$tmp/cache"
  mkdir -p "$state"
  : >"$state/calls"
}

run() {
  env PATH="$bin:$PATH" XDG_CACHE_HOME="$tmp/cache" TSH_STATE="$state" "$wrapper" "$@"
}

count() {
  grep -c -x -- "$1" "$state/calls" || true
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Workspaces restart together with an expired session; only one logs in.
reset
pids=()
for i in 1 2 3 4; do
  LOGIN_DELAY=1 run db start uri >"$tmp/out.$i" 2>/dev/null &
  pids+=("$!")
done
wait "${pids[@]}"
[[ $(count login) == 1 ]] || fail 'concurrent starts must share one login'
[[ $(count 'mcp db start uri') == 4 ]] || fail 'every start must run tsh mcp'
for i in 1 2 3 4; do
  # Login output on stdout would corrupt the MCP protocol stream.
  [[ $(cat "$tmp/out.$i") == mcp-stdout ]] || fail 'stdout must carry only MCP output'
done

# A client may kill a start that waits on the browser, including its whole
# process group; the login keeps running and holds the lock.
reset
set -m
env PATH="$bin:$PATH" XDG_CACHE_HOME="$tmp/cache" TSH_STATE="$state" LOGIN_DELAY=2 \
  "$wrapper" db start uri >/dev/null 2>&1 &
first=$!
set +m
sleep 0.5
kill -- "-$first"
wait "$first" 2>/dev/null || true
run db start uri >/dev/null 2>&1
[[ $(count login) == 1 ]] || fail 'a pending login must block other logins'
[[ $(count 'mcp db start uri') == 1 ]]

# A failed login exits instead of letting tsh open its own, and is not retried at once.
reset
if LOGIN_FAILS=1 run db start uri >/dev/null 2>&1; then
  fail 'a failed login must exit non-zero'
fi
if LOGIN_FAILS=1 run db start uri >/dev/null 2>&1; then
  fail 'a start right after a failed login must exit non-zero'
fi
[[ $(count login) == 1 ]] || fail 'a failed login must not be retried immediately'
[[ $(count 'mcp db start uri') == 0 ]]

# A valid session starts straight away.
reset
touch "$state/session"
[[ $(run db start uri 2>/dev/null) == mcp-stdout ]]
[[ $(count login) == 0 ]]

printf '%s\n' 'tsh-mcp tests passed'
