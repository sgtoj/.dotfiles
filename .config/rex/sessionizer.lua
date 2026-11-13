local home = os.getenv("HOME")
local picker = home .. "/.local/bin/rex-sessionizer"
local run_dir = home .. "/.cache/rex-sessionizer/run"
local curl = "/usr/bin/curl"

local function find_rex()
  local candidates = {
    home .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
    "/usr/bin/rex",
    "/usr/local/bin/rex",
  }
  for _, path in ipairs(candidates) do
    local file = io.open(path)
    if file then
      file:close()
      return path
    end
  end
  return "rex"
end

local rex_dir = find_rex():match("^(.*)/[^/]+$") or ""

local function socket_for(block_id)
  return run_dir .. "/" .. (block_id or ""):gsub("^block:", "") .. ".sock"
end

local function picker_state(ctx)
  local socket = socket_for(ctx.block_id)
  local r = rex.exec({ curl, "--silent", "--fail", "--max-time", "1", "--unix-socket", socket, "http://localhost/?limit=0" })
  if r == nil or not r.ok then return nil end
  return socket, rex.json.decode(r.stdout)
end

local function close_picker(socket)
  rex.exec({ curl, "--silent", "--max-time", "1", "--unix-socket", socket, "--data", "abort", "http://localhost/" })
  rex.client.queue("client.mode.exit")
end

local function pass_through(key)
  rex.client.queue("client.mode.exit")
  rex.client.queue("pane.send_key", { key = key })
end

local function fields(text)
  local out = {}
  for field in (text .. "\t"):gmatch("([^\t]*)\t") do
    table.insert(out, field)
  end
  return out
end

rex.action{
  name = "sessionizer",
  title = "Open Project or Session…",
  description = "Pick a project, worktree, or running session and switch to it.",
  category = "Session",
  keywords = "project repo worktree sessionizer fzf open switch",
  run = function(ctx)
    local layer, err = rex.session.new_layer{
      bounds = { 0.06, 0.06, 0.88, 0.88 },
      focus = true,
      layout = rex.layout.block{
        flavor = "com.superlogical.terminal.shell",
        options = { command = { picker, "--pick", run_dir } },
      },
    }
    if layer == nil then error(err, 0) end
    rex.client.queue("client.mode.enter", { name = "sessionizer" })
  end,
}

rex.action{
  name = "sessionizer_accept",
  title = "Sessionizer: Open Selection",
  category = "Session",
  args = { tab = "boolean?" },
  run = function(ctx, args)
    local socket, state = picker_state(ctx)
    if socket == nil then return pass_through(args.tab and "alt+enter" or "enter") end
    local current = state and state.current
    if current == nil then return end

    local row = fields(current.text or "")
    local kind, target = row[4], row[5]
    if kind ~= "session" and kind ~= "dir" then return end
    local session_id
    if kind == "session" then
      session_id = target
    elseif kind == "dir" then
      local r, err = rex.exec(
        { picker, args.tab and "--open-tab" or "--open", target },
        { env = { REX_BIN_DIR = rex_dir, REX_SESSION = ctx.session_id }, timeout = 20 }
      )
      if r == nil then error(err, 0) end
      if not r.ok then error(r.stderr, 0) end
      session_id = r.stdout:match("[^\r\n]+")
    end

    close_picker(socket)
    if session_id and session_id ~= ctx.session_id then
      rex.client.queue("session.select", { session_id = session_id })
    end
  end,
}

rex.action{
  name = "sessionizer_cancel",
  title = "Sessionizer: Close",
  category = "Session",
  args = { key = "string?", action = "string?" },
  run = function(ctx, args)
    local socket = picker_state(ctx)
    if socket ~= nil then return close_picker(socket) end
    if args.action then
      rex.client.queue("client.mode.exit")
      rex.client.queue(args.action)
      return
    end
    pass_through(args.key or "escape")
  end,
}

rex.bind("cmd+o", "sessionizer")
rex.bind("sessionizer/enter", "sessionizer_accept")
rex.bind("sessionizer/alt+enter", "sessionizer_accept", { tab = true })
rex.bind("sessionizer/escape", "sessionizer_cancel", { key = "escape" })
rex.bind("sessionizer/ctrl+c", "sessionizer_cancel", { key = "ctrl+c" })
rex.bind("sessionizer/cmd+w", "sessionizer_cancel", { action = "client.close" })
