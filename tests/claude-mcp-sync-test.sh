#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
sync="$repo_root/.local/bin/claude-mcp-sync"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
home="$tmp/home"
log="$tmp/claude.log"
claude_dir="$tmp/claude"
mkdir -p "$bin" "$home/.config/opencode" "$home/.secrets/opencode" "$claude_dir"

cat >"$bin/claude" <<'EOF'
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

path = Path(os.environ["CLAUDE_CONFIG_DIR"]) / ".claude.json"
data = json.loads(path.read_text())
servers = data.setdefault("mcpServers", {})
args = sys.argv[1:]
assert args[:1] == ["mcp"] and args[2:4] == ["--scope", "user"], args
action, name = args[1], args[4]
if action == "add-json":
    assert name not in servers, f"{name} already exists"
    servers[name] = json.loads(args[5])
    line = f"add {name}"
    if "--client-secret" in args:
        line += f" secret={os.environ['MCP_CLIENT_SECRET']}"
elif action == "remove":
    del servers[name]
    line = f"remove {name}"
path.write_text(json.dumps(data))
with open(os.environ["CLAUDE_LOG"], "a") as log:
    log.write(line + "\n")
EOF
chmod +x "$bin/claude"

cat >"$home/.config/opencode/opencode.json" <<'EOF'
{
  // public servers
  "mcp": {
    "servers": {
      "chrome-devtools": {
        "type": "local",
        "command": ["npx", "-y", "chrome-devtools-mcp@latest"],
        "disabled": false,
      },
      "shared": { "type": "local", "command": ["public"] },
    },
  },
}
EOF

printf 'file-token\n' >"$home/.secrets/opencode/token"
cat >"$home/.secrets/opencode/opencode.private.json" <<'EOF'
{
  "mcp": {
    "servers": {
      "shared": { "type": "local", "command": ["private", "--flag"] },
      "grafana": {
        "type": "remote",
        "url": "https://grafana.internal.example/mcp",
        "oauth": false,
        "headers": {
          "Authorization": "Bearer {env:GRAFANA_TOKEN}",
          "X-File": "{file:./token}",
        },
        "timeout": { "execution": 600000 },
      },
      "sso": {
        "type": "remote",
        "url": "https://sso.internal.example/mcp",
        "oauth": {
          "client_id": "client-1",
          "client_secret": "{env:SSO_SECRET}",
          "redirect_uri": "http://127.0.0.1:19876/callback",
        },
      },
      "off": { "type": "local", "command": ["off"], "disabled": true },
    },
    "legacy": { "type": "local", "command": ["legacy"], "enabled": true },
  },
}
EOF

printf '%s\n' '{"mcpServers":{"stale":{"type":"stdio","command":"old","args":[]}}}' >"$claude_dir/.claude.json"

run() {
  env -u OPENCODE_CONFIG -u XDG_CONFIG_HOME \
    HOME="$home" PATH="$bin:$PATH" CLAUDE_CONFIG_DIR="$claude_dir" CLAUDE_LOG="$log" \
    SSO_SECRET=sso-secret "$sync" "$@"
}

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

server() {
  jq -c --arg name "$1" '.mcpServers[$name]' "$claude_dir/.claude.json"
}

run --dry-run >"$tmp/out"
[[ ! -s $log ]] || fail 'dry run must not change Claude config'
grep -Fqx 'would add grafana' "$tmp/out"

run >"$tmp/out"

# Private endpoints and credentials stay out of the output.
if grep -Eq 'internal|token|secret|client-1' "$tmp/out"; then
  fail 'output must contain only server names'
fi

[[ $(server chrome-devtools) == '{"type":"stdio","command":"npx","args":["-y","chrome-devtools-mcp@latest"]}' ]]
# The private config overrides a public server with the same name.
[[ $(server shared) == '{"type":"stdio","command":"private","args":["--flag"]}' ]]
[[ $(server legacy) == '{"type":"stdio","command":"legacy","args":[]}' ]]
# Env references stay symbolic; file references are inlined.
[[ $(server grafana) == '{"type":"http","url":"https://grafana.internal.example/mcp","headers":{"Authorization":"Bearer ${GRAFANA_TOKEN}","X-File":"file-token"},"timeout":600000}' ]]
[[ $(server sso) == '{"type":"http","url":"https://sso.internal.example/mcp","oauth":{"clientId":"client-1","callbackPort":19876}}' ]]
grep -Fqx 'add sso secret=sso-secret' "$log"
[[ $(server off) == null ]]
grep -Fqx 'skip off (disabled)' "$tmp/out"
[[ $(server stale) != null ]] || fail 'servers are kept without --prune'
grep -Fqx 'extra stale (not in OpenCode; --prune removes it)' "$tmp/out"

# Unchanged servers are not re-added, which would discard OAuth sign-ins.
: >"$log"
run >"$tmp/out"
[[ ! -s $log ]] || fail 'a second sync must not touch Claude config'
grep -Fqx 'unchanged sso' "$tmp/out"

run --prune >"$tmp/out"
grep -Fqx 'remove stale' "$log"
[[ $(server stale) == null ]]

printf '%s\n' 'claude-mcp-sync tests passed'
