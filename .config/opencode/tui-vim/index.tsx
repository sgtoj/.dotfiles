/** @jsxImportSource @opentui/solid */

import { spawnSync } from "node:child_process"
import type {
  KeyEvent,
  Renderable,
  TuiPlugin,
  TuiPluginApi,
  TuiPluginModule,
} from "@opencode-ai/plugin/tui"
import {
  ScrollBoxRenderable,
  TextAttributes,
  type CursorStyleOptions,
  type EditBufferRenderable,
} from "@opentui/core"
import type { Binding, CommandContext, KeyLike } from "@opentui/keymap"
import { createEffect, createMemo, createSignal, For, onCleanup, onMount, Show } from "solid-js"
import {
  currentSelection,
  handleKey,
  initialState,
  modeLabel,
  pendingLabel,
  trackInsert,
  type Frame,
  type Register,
  type VimState,
} from "./engine"
import { graphemes, normalCursor } from "./text"
import {
  buildTranscript,
  copySelection,
  copyStatus,
  currentSearchRange,
  cursorGraphemeEnd,
  cursorPoint,
  handleCopyKey,
  initialCopyState,
  lineOffset,
  nextLineOffset,
  rangeContains,
  setCopySearch,
  type CopyState,
  type TranscriptDocument,
} from "./transcript"

const PLUGIN_ID = "local.vim"
const PROMPT_MODE = "local.vim.prompt"
const COPY_MODE = "local.vim.copy"
const COMMAND_TOGGLE = "local.vim.toggle"
const COMMAND_PROMPT_KEY = "local.vim.prompt.key"
const COMMAND_COPY_KEY = "local.vim.copy.key"
const KV_ENABLED = "local.vim.enabled"

type InitialMode = "insert" | "normal"

type Options = {
  enabled: boolean
  initialMode: InitialMode
  indicator: boolean
  clipboard: boolean
  copyReasoning: boolean
  copyToolOutput: boolean
}

type Editor = EditBufferRenderable & {
  focused?: boolean
  isDestroyed: boolean
  submit(): boolean
}

type ModalEditor = EditBufferRenderable & { isDestroyed: boolean }

type Appearance = {
  showCursor: boolean
  cursorStyle: CursorStyleOptions
  selectionBg: Editor["selectionBg"]
  selectionFg: Editor["selectionFg"]
}

function object(value: unknown): Record<string, unknown> | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined
}

function readOptions(value: unknown): Options {
  const options = object(value) ?? {}
  const initial = options.initial_mode ?? options.vim_initial_mode
  return {
    enabled: options.enabled !== false,
    initialMode: initial === "normal" ? "normal" : "insert",
    indicator: options.indicator !== false,
    clipboard: options.system_clipboard !== false,
    copyReasoning: options.copy_reasoning === true,
    copyToolOutput: options.copy_tool_output === true,
  }
}

function eventKey(event: KeyEvent) {
  const name = event.name.toLowerCase()
  if (event.ctrl && !event.meta && !event.super) return `ctrl+${name}`
  if (name === "return" || name === "enter") return "return"
  if (name === "escape" || name === "esc") return "escape"
  if (name === "space") return "space"
  if (name === "backspace" || name === "delete" || name === "left" || name === "right" || name === "up" || name === "down") return name
  const value = graphemes(event.sequence ?? "").length === 1
    ? event.sequence
    : graphemes(event.raw ?? "").length === 1
      ? event.raw
      : undefined
  if (value === " ") return "space"
  if (value && value >= " ") return value
  return event.shift && name.length === 1 ? name.toUpperCase() : name
}

function normalKeys(): KeyLike[] {
  const keys = new Set<string>([
    "escape",
    "return",
    "space",
    "backspace",
    "delete",
    "left",
    "right",
    "up",
    "down",
    "ctrl+r",
    "ctrl+w",
    "ctrl+v",
    "ctrl+d",
    "ctrl+u",
    "ctrl+f",
    "ctrl+b",
    "ctrl+e",
    "ctrl+y",
  ])
  for (const key of "abcdefghijklmnopqrstuvwxyz") {
    keys.add(key)
    keys.add(`shift+${key}`)
  }
  for (const key of "0123456789") {
    keys.add(key)
    keys.add(`shift+${key}`)
  }
  for (const key of ["-", "=", "[", "]", "\\", ";", "'", ".", "/", "`", "shift+-", "shift+=", "shift+[", "shift+]", "shift+\\", "shift+;", "shift+'", "shift+.", "shift+/", "shift+`"]) keys.add(key)
  for (const key of ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "{", "}", "|", ":", '"', "<", ">", "?", "~"]) keys.add(key)
  return [...keys, { name: "," }, { name: ",", shift: true }]
}

function isPromptEditor(api: TuiPluginApi, value: unknown = api.renderer.currentFocusedEditor): value is Editor {
  if (api.ui.dialog.open) return false
  if (api.route.current.name !== "home" && api.route.current.name !== "session") return false
  if (!value || typeof value !== "object") return false
  const candidate = value as unknown as Partial<Editor>
  if (candidate.isDestroyed) return false
  const traits = object(candidate.traits)
  if (traits?.owner !== "opencode" || traits.role !== "prompt" || traits.status === "SHELL") return false
  return (
    typeof candidate.plainText === "string" &&
    typeof candidate.cursorOffset === "number" &&
    typeof candidate.insertText === "function" &&
    typeof candidate.deleteRange === "function" &&
    typeof candidate.submit === "function"
  )
}

function isModalEditor(api: TuiPluginApi, value: unknown = api.renderer.currentFocusedEditor): value is ModalEditor {
  if (!api.ui.dialog.open || !value || typeof value !== "object") return false
  const candidate = value as Partial<ModalEditor>
  return !candidate.isDestroyed && typeof candidate.plainText === "string" && typeof candidate.cursorOffset === "number"
}

function frame(editor: Editor): Frame {
  return { text: editor.plainText, cursor: editor.cursorOffset }
}

function minimalEdit(before: string, after: string) {
  let start = 0
  while (start < before.length && start < after.length && before[start] === after[start]) start++
  let suffix = 0
  while (
    suffix < before.length - start &&
    suffix < after.length - start &&
    before[before.length - suffix - 1] === after[after.length - suffix - 1]
  )
    suffix++
  return {
    start,
    oldEnd: before.length - suffix,
    value: after.slice(start, after.length - suffix),
  }
}

function applyFrame(editor: Editor, before: Frame, after: Frame) {
  if (before.text !== after.text) {
    const edit = minimalEdit(before.text, after.text)
    const start = editor.editBuffer.offsetToPosition(edit.start)
    const end = editor.editBuffer.offsetToPosition(edit.oldEnd)
    if (!start || !end) {
      editor.replaceText(after.text)
    } else {
      editor.cursorOffset = edit.start
      if (edit.oldEnd > edit.start) editor.deleteRange(start.row, start.col, end.row, end.col)
      editor.cursorOffset = edit.start
      if (edit.value) editor.insertText(edit.value)
    }
  }
  editor.cursorOffset = Math.max(0, Math.min(after.cursor, editor.plainText.length))
}

function isPrintable(event: KeyEvent) {
  if (event.ctrl || event.meta || event.super || event.hyper) return false
  if (event.name === "space") return true
  const value = event.sequence || event.raw
  return !!value && !/[\x00-\x1f\x7f]/u.test(value)
}

function clipboardWrite(api: TuiPluginApi, value: string) {
  let copied = false
  if (process.platform === "darwin") {
    const result = spawnSync("pbcopy", [], { input: value, encoding: "utf8", stdio: ["pipe", "ignore", "ignore"] })
    copied = result.status === 0
  }
  if (!copied) {
    try {
      copied = api.renderer.copyToClipboardOSC52(value)
    } catch {}
  }
  return copied
}

async function loadTranscript(api: TuiPluginApi, sessionID: string, signal: AbortSignal) {
  const pages: Array<Array<{ info: unknown; parts: unknown[] }>> = []
  const seen = new Set<string>()
  let before: string | undefined
  do {
    const response = await (api.client.session.messages as any)(
      { sessionID, limit: 100, ...(before ? { before } : {}) },
      { throwOnError: true, signal },
    )
    const data = Array.isArray(response.data) ? response.data : []
    pages.unshift(data)
    const next = response.response?.headers?.get?.("X-Next-Cursor") || undefined
    if (!next || seen.has(next)) break
    seen.add(next)
    before = next
  } while (!signal.aborted && pages.reduce((total, page) => total + page.length, 0) < 1000)
  return pages.flat()
}

function lineColor(api: TuiPluginApi, kind: string) {
  if (kind === "speaker") return api.theme.current.primary
  if (kind === "reasoning") return api.theme.current.textMuted
  if (kind === "tool" || kind === "file") return api.theme.current.secondary
  return api.theme.current.text
}

function CopyLine(props: {
  api: TuiPluginApi
  document: TranscriptDocument
  state: () => CopyState
  index: number
}) {
  const line = () => props.document.lines[props.index]!
  const start = () => lineOffset(props.document, props.index)
  const visible = createMemo(() => {
    const items = graphemes(line().text)
    return items.length ? items : [{ segment: " ", index: 0 }]
  })
  const selection = () => copySelection(props.state(), props.document)
  const currentSearch = () => currentSearchRange(props.state())
  const decorated = createMemo(() => {
    const from = start()
    const to = nextLineOffset(props.document, props.index)
    const intersects = (range: { start: number; end: number } | undefined) => !!range && range.start < to && range.end > from
    return (
      (props.state().cursor >= from && (props.state().cursor < to || (from === to && props.state().cursor === from))) ||
      intersects(selection()) ||
      props.state().matches.some(intersects)
    )
  })

  return (
    <text
      id={`local-vim-copy-${props.index}`}
      wrapMode="none"
      fg={lineColor(props.api, line().kind)}
      attributes={line().kind === "speaker" ? TextAttributes.BOLD : undefined}
    >
      <Show
        when={decorated()}
        fallback={
          <span style={{ bg: props.api.theme.current.background, fg: lineColor(props.api, line().kind) }}>
            {line().text || " "}
          </span>
        }
      >
        <For each={visible()}>
          {(item) => {
            const offset = () => start() + item.index
            const selected = () => rangeContains(selection(), offset())
            const searched = () => props.state().matches.some((range) => rangeContains(range, offset()))
            const current = () => rangeContains(currentSearch(), offset())
            const cursor = () => props.state().cursor === offset()
            return (
              <span
                style={{
                  bg: cursor()
                    ? props.api.theme.current.text
                    : selected()
                      ? props.api.theme.current.secondary
                      : current()
                        ? props.api.theme.current.primary
                        : searched()
                          ? props.api.theme.current.textMuted
                          : props.api.theme.current.background,
                  fg: cursor() || selected() || current() || searched()
                    ? props.api.theme.current.background
                    : lineColor(props.api, line().kind),
                }}
              >
                {item.segment}
              </span>
            )
          }}
        </For>
      </Show>
    </text>
  )
}

function CopyRoute(props: {
  api: TuiPluginApi
  sessionID: string
  options: Options
  setRegister: (register: Register) => void
  focusPrompt: () => void
  leave: () => void
}) {
  const [document, setDocument] = createSignal<TranscriptDocument>()
  const [state, setState] = createSignal<CopyState>()
  const [error, setError] = createSignal("")
  let scroll: ScrollBoxRenderable | undefined
  const controller = new AbortController()
  const popMode = props.api.mode.push(COPY_MODE)
  const timers = new Set<ReturnType<typeof setTimeout>>()
  let searchOpen = false

  const disposeKeys = props.api.keymap.registerLayer({
    mode: COPY_MODE,
    priority: 300,
    commands: [
      {
        name: COMMAND_COPY_KEY,
        title: "Vim copy key",
        hidden: true,
        run(ctx: CommandContext<Renderable, KeyEvent>) {
          const doc = document()
          const current = state()
          if (!doc || !current) return true
          const step = handleCopyKey(current, doc, eventKey(ctx.event))
          setState(step.state)
          for (const effect of step.effects) {
            if (effect.type === "exit") props.leave()
            if (effect.type === "focus-prompt") props.focusPrompt()
            if (effect.type === "bell") continue
            if (effect.type === "yank") {
              props.setRegister({ text: effect.text.replace(/\n$/u, ""), linewise: effect.linewise })
              const copied = props.options.clipboard && clipboardWrite(props.api, effect.text)
              props.api.ui.toast({ message: copied ? "Yanked to clipboard" : "Yanked to Vim register", variant: "info" })
            }
            if (effect.type === "search") {
              searchOpen = true
              props.api.ui.dialog.replace(() =>
                props.api.ui.DialogPrompt({
                  title: effect.direction === 1 ? "Search forward" : "Search backward",
                  value: step.state.query,
                  onConfirm(value) {
                    const latest = state()
                    const latestDocument = document()
                    if (latest && latestDocument) setState(setCopySearch(latest, latestDocument, value, effect.direction))
                    searchOpen = false
                    props.api.ui.dialog.clear()
                  },
                  onCancel() {
                    searchOpen = false
                    props.api.ui.dialog.clear()
                  },
                }),
              )
            }
          }
          return true
        },
      },
    ],
    bindings: normalKeys().map((key) => ({ key, cmd: COMMAND_COPY_KEY })),
  })

  onMount(() => {
    void loadTranscript(props.api, props.sessionID, controller.signal)
      .then((messages) => {
        if (controller.signal.aborted) return
        const next = buildTranscript(messages, {
          reasoning: props.options.copyReasoning,
          toolOutput: props.options.copyToolOutput,
        })
        setState(initialCopyState(next))
        setDocument(next)
      })
      .catch((cause) => {
        if (!controller.signal.aborted) setError(cause instanceof Error ? cause.message : String(cause))
      })
  })

  createEffect(() => {
    const doc = document()
    const current = state()
    if (!doc || !current) return
    const row = cursorPoint(current, doc).line
    const timer = setTimeout(() => {
      timers.delete(timer)
      scroll?.scrollChildIntoView(`local-vim-copy-${row}`)
    }, 0)
    timers.add(timer)
  })

  onCleanup(() => {
    controller.abort()
    if (searchOpen) props.api.ui.dialog.clear()
    disposeKeys()
    popMode()
    for (const timer of timers) clearTimeout(timer)
  })

  return (
    <box flexGrow={1} minHeight={0} flexDirection="column" paddingLeft={2} paddingRight={2}>
      <box height={1} flexShrink={0} flexDirection="row" justifyContent="space-between">
        <text fg={props.api.theme.current.primary} attributes={TextAttributes.BOLD}>Transcript</text>
        <text fg={props.api.theme.current.textMuted}>{props.sessionID.slice(0, 12)}</text>
      </box>
      <Show when={document()} fallback={<text fg={error() ? props.api.theme.current.error : props.api.theme.current.textMuted}>{error() || "Loading transcript..."}</text>}>
        {(doc) => (
          <scrollbox
            ref={(value: ScrollBoxRenderable) => (scroll = value)}
            flexGrow={1}
            minHeight={0}
            scrollX
            scrollY
            viewportCulling
          >
            <For each={doc().lines}>
              {(_line, index) => <CopyLine api={props.api} document={doc()} state={() => state()!} index={index()} />}
            </For>
          </scrollbox>
        )}
      </Show>
      <box height={1} flexShrink={0} flexDirection="row" justifyContent="space-between">
        <text fg={props.api.theme.current.primary}>{state() ? copyStatus(state()!) : "-- COPY --"}</text>
        <text fg={props.api.theme.current.textMuted}>v/V select · y yank · / search · i prompt · q close</text>
      </box>
    </box>
  )
}

const tui: TuiPlugin = async (api, rawOptions) => {
  const options = readOptions(rawOptions)
  const [enabled, setEnabled] = createSignal(api.kv.get(KV_ENABLED, options.enabled))
  const [vim, setVim] = createSignal<VimState>(initialState(options.initialMode))
  const [register, setRegister] = createSignal<Register>(null)
  const [modalMode, setModalMode] = createSignal<"insert" | "normal">("insert")
  const appearances = new Map<Editor, Appearance>()
  let popPromptMode: (() => void) | undefined
  let windowPending = false
  let lastEditor: Editor | undefined
  let syncing = false
  let lastModalEditor: ModalEditor | undefined
  let modalPending = ""
  const returnTimers = new Set<ReturnType<typeof setTimeout>>()

  function editor() {
    const value = api.renderer.currentFocusedEditor
    return isPromptEditor(api, value) ? value : undefined
  }

  function rememberAppearance(value: Editor) {
    if (appearances.has(value)) return
    appearances.set(value, {
      showCursor: value.showCursor,
      cursorStyle: value.cursorStyle,
      selectionBg: value.selectionBg,
      selectionFg: value.selectionFg,
    })
  }

  function restoreAppearance(value: Editor) {
    const original = appearances.get(value)
    if (!original || value.isDestroyed) return
    value.showCursor = original.showCursor
    value.cursorStyle = original.cursorStyle
    value.selectionBg = original.selectionBg
    value.selectionFg = original.selectionFg
    value.clearSelection()
    value.requestRender()
  }

  function applyAppearance(value: Editor, state: VimState, current: Frame) {
    rememberAppearance(value)
    value.showCursor = true
    value.cursorStyle = state.mode === "insert"
      ? { style: "line", blinking: true }
      : state.mode === "replace"
        ? { style: "underline", blinking: false }
        : { style: "block", blinking: false }
    value.selectionBg = api.theme.current.secondary
    value.selectionFg = api.theme.current.background
    const selection = currentSelection(state, current)
    if (selection) {
      value.setSelection(selection.start, selection.end)
      value.cursorOffset = current.cursor
    } else {
      value.clearSelection()
    }
    value.requestRender()
  }

  function popPrompt() {
    popPromptMode?.()
    popPromptMode = undefined
  }

  function syncPromptMode() {
    if (syncing) return
    syncing = true
    try {
      for (const item of appearances.keys()) {
        if (item.isDestroyed) appearances.delete(item)
      }
      const active = editor()
      if (active !== lastEditor) {
        lastEditor = active
        if (active) {
          const clean = { ...initialState(vim().mode), register: register() }
          setVim(trackInsert(clean, frame(active)))
        }
      }
      const shouldPush = enabled() && !!active && vim().mode !== "insert"
      if (shouldPush && !popPromptMode) popPromptMode = api.mode.push(PROMPT_MODE)
      if (!shouldPush) popPrompt()
      if (active && enabled()) applyAppearance(active, vim(), frame(active))
      if (active && !enabled()) restoreAppearance(active)
    } finally {
      syncing = false
    }
  }

  function setState(state: VimState) {
    const previous = register()
    if (state.register) {
      setRegister(state.register)
      if (
        options.clipboard &&
        (previous?.text !== state.register.text || previous.linewise !== state.register.linewise)
      ) {
        clipboardWrite(api, state.register.text)
      }
    }
    setVim({ ...state, register: state.register ?? register() })
    syncPromptMode()
  }

  function resetPending() {
    const current = editor()
    if (!current) return
    const step = handleKey(vim(), frame(current), "escape")
    setState(step.state)
  }

  function openCopy() {
    const route = api.route.current
    if (route.name !== "session" || !("params" in route) || typeof route.params?.sessionID !== "string") return false
    popPrompt()
    api.route.navigate("local.vim.copy", { sessionID: route.params.sessionID })
    return true
  }

  function returnToSession(sessionID: string, insert = false) {
    popPrompt()
    if (insert) setVim({ ...vim(), mode: "insert", pending: null, count: "", visualAnchor: undefined })
    api.route.navigate("session", { sessionID })
    const timer = setTimeout(() => {
      returnTimers.delete(timer)
      const value = editor()
      value?.focus()
      syncPromptMode()
    }, 0)
    returnTimers.add(timer)
  }

  function sessionCommand(name: string) {
    void api.keymap.runCommand(name)
  }

  function handleWindowKey(key: string) {
    if (windowPending) {
      windowPending = false
      if (key === "k" || key === "w" || key === "ctrl+w") return openCopy()
      if (key === "j" || key === "i") {
        const value = editor()
        if (value) {
          setState({ ...vim(), mode: "insert", pending: null, count: "", visualAnchor: undefined })
          value.focus()
        }
        return true
      }
      return true
    }
    if (key !== "ctrl+w") return false
    windowPending = true
    return true
  }

  function handleSessionNavigation(key: string, current: Frame) {
    const run = (name: string) => {
      sessionCommand(name)
      return true
    }
    if (key === "ctrl+d") return run("session.half.page.down")
    if (key === "ctrl+u") return run("session.half.page.up")
    if (key === "ctrl+f") return run("session.page.down")
    if (key === "ctrl+b") return run("session.page.up")
    if (key === "ctrl+e") return run("session.line.down")
    if (key === "ctrl+y") return run("session.line.up")
    if (current.text) return false
    if (key === "j") return run("session.line.down")
    if (key === "k") return run("session.line.up")
    if (key === "G") {
      resetPending()
      return run("session.last")
    }
    if (key === "}") {
      resetPending()
      return run("session.message.next")
    }
    if (key === "{") {
      resetPending()
      return run("session.message.previous")
    }
    if (key === "v" || key === "ctrl+v") return openCopy()
    if (key === "y") return run("messages.copy")
    if (key === "g" && pendingLabel(vim()) === "g") {
      resetPending()
      return run("session.first")
    }
    return false
  }

  function promptKey(ctx: CommandContext<Renderable, KeyEvent>) {
    const value = isPromptEditor(api, ctx.focused) ? ctx.focused : editor()
    if (!value || !enabled()) return false
    const key = eventKey(ctx.event)
    const before = frame(value)

    if (vim().mode === "insert" && key === "return") {
      const next = trackInsert({ ...initialState("insert"), register: register() }, { text: "", cursor: 0 })
      setState(next)
      value.submit()
      return true
    }

    if (vim().mode !== "insert" && handleWindowKey(key)) return true
    if (vim().mode !== "insert" && handleSessionNavigation(key, before)) return true
    if (vim().mode === "normal" && key === "escape" && !pendingLabel(vim())) {
      sessionCommand("session.interrupt")
      return true
    }
    if (vim().mode === "normal" && (key === "u" || key === "ctrl+r")) {
      const step = handleKey({ ...vim(), register: register() }, before, key)
      let attempts = 0
      while (value.plainText !== step.frame.text && attempts < 1000) {
        attempts++
        const changed = key === "u" ? value.undo() : value.redo()
        if (!changed) break
      }
      if (value.plainText !== step.frame.text) applyFrame(value, frame(value), step.frame)
      value.cursorOffset = step.frame.cursor
      setState(step.state)
      return true
    }

    const step = handleKey({ ...vim(), register: register() }, before, key)
    applyFrame(value, before, step.frame)
    let next = step.state
    for (const effect of step.effects) {
      if (effect.type === "palette") api.keymap.dispatchCommand("command.palette.show")
      if (effect.type === "submit") {
        next = trackInsert({ ...initialState("insert"), register: register() }, { text: "", cursor: 0 })
        value.submit()
      }
    }
    setState(next)
    applyAppearance(value, next, frame(value))
    return step.handled
  }

  function handleModalKey(value: ModalEditor, key: string) {
    const run = (name: string) => {
      api.keymap.runCommand(name)
      return true
    }
    if (modalMode() === "insert") {
      if (key !== "escape") return false
      modalPending = ""
      setModalMode("normal")
      value.cursorOffset = normalCursor(value.plainText, value.cursorOffset)
      value.cursorStyle = { style: "block", blinking: false }
      return true
    }

    if (modalPending === "g") {
      modalPending = ""
      if (key === "g") api.keymap.runCommand("dialog.select.home")
      return true
    }
    if (modalPending === "d") {
      modalPending = ""
      if (key === "d") {
        value.clear()
        value.cursorOffset = 0
      }
      return true
    }

    if (key === "escape" || key === "q") {
      setModalMode("insert")
      api.ui.dialog.clear()
      return true
    }
    if (key === "i" || key === "/") {
      setModalMode("insert")
      value.cursorStyle = { style: "line", blinking: true }
      value.focus()
      return true
    }
    if (key === "a") {
      value.moveCursorRight()
      setModalMode("insert")
      value.cursorStyle = { style: "line", blinking: true }
      return true
    }
    if (key === "I") {
      value.gotoLineHome()
      setModalMode("insert")
      return true
    }
    if (key === "A") {
      value.gotoLineEnd()
      setModalMode("insert")
      return true
    }
    if (key === "h") {
      value.moveCursorLeft()
      return true
    }
    if (key === "l") {
      value.moveCursorRight()
      return true
    }
    if (key === "w") {
      value.moveWordForward()
      return true
    }
    if (key === "b") {
      value.moveWordBackward()
      return true
    }
    if (key === "0") {
      value.gotoLineHome()
      return true
    }
    if (key === "$") {
      value.gotoLineEnd()
      return true
    }
    if (key === "x") {
      value.deleteChar()
      return true
    }
    if (key === "s") {
      value.deleteChar()
      setModalMode("insert")
      return true
    }
    if (key === "d") {
      modalPending = "d"
      return true
    }
    if (key === "g") {
      modalPending = "g"
      return true
    }
    if (key === "G") return run("dialog.select.end")
    if (key === "j") return run("dialog.select.next")
    if (key === "k") return run("dialog.select.prev")
    if (key === "ctrl+d") return run("dialog.select.page_down")
    if (key === "ctrl+u") return run("dialog.select.page_up")
    if (key === "return") return run("dialog.select.submit")
    return true
  }

  function toggle() {
    const next = !enabled()
    api.kv.set(KV_ENABLED, next)
    setEnabled(next)
    const value = editor()
    if (!next) {
      popPrompt()
      setVim(initialState("insert"))
      for (const item of appearances.keys()) restoreAppearance(item)
    } else {
      const state = initialState(options.initialMode)
      setVim(value && options.initialMode === "insert" ? trackInsert(state, frame(value)) : state)
      syncPromptMode()
    }
    value?.focus()
    api.ui.toast({ message: next ? "Vim mode enabled" : "Vim mode disabled", variant: next ? "success" : "info" })
    api.ui.dialog.clear()
  }

  api.keymap.registerLayer({
    commands: [
      {
        name: COMMAND_TOGGLE,
        title: "Toggle Vim mode",
        category: "Plugin",
        namespace: "palette",
        slashName: "vim",
        run: toggle,
      },
      {
        name: COMMAND_PROMPT_KEY,
        title: "Vim prompt key",
        hidden: true,
        run: promptKey,
      },
    ],
  })

  api.keymap.registerLayer({
    mode: "base",
    priority: 300,
    enabled: () => enabled() && vim().mode === "insert" && !!editor(),
    bindings: [
      { key: "escape", cmd: COMMAND_PROMPT_KEY },
      { key: "return", cmd: COMMAND_PROMPT_KEY },
    ],
  })

  api.keymap.registerLayer({
    mode: PROMPT_MODE,
    priority: 300,
    enabled: () => enabled() && !!editor(),
    bindings: normalKeys().map((key): Binding<Renderable, KeyEvent> => ({ key, cmd: COMMAND_PROMPT_KEY })),
  })

  api.keymap.intercept("key:after", ({ event, focused, handled, consume }) => {
    if (api.mode.current() !== PROMPT_MODE || handled || !isPromptEditor(api, focused)) return
    if (isPrintable(event)) consume()
  })

  api.keymap.intercept(
    "key",
    ({ event, consume }) => {
      if (!enabled()) return
      const focused = api.renderer.currentFocusedEditor
      if (!isModalEditor(api, focused)) return
      if (modalMode() === "insert" && eventKey(event) !== "escape") return
      if (handleModalKey(focused, eventKey(event))) consume()
    },
    { priority: 500 },
  )

  api.route.register([
    {
      name: "local.vim.copy",
      render(input) {
        const sessionID = typeof input.params?.sessionID === "string" ? input.params.sessionID : ""
        return (
          <CopyRoute
            api={api}
            sessionID={sessionID}
            options={options}
            setRegister={(value) => {
              setRegister(value)
              setVim((state) => ({ ...state, register: value }))
            }}
            focusPrompt={() => returnToSession(sessionID, true)}
            leave={() => returnToSession(sessionID)}
          />
        )
      },
    },
  ])

  api.keymap.on("state", () => {
    const focused = api.renderer.currentFocusedEditor
    const current = isModalEditor(api, focused) ? focused : undefined
    if (current !== lastModalEditor) {
      lastModalEditor = current
      modalPending = ""
      setModalMode("insert")
    }
    syncPromptMode()
  })

  function Status() {
    createEffect(syncPromptMode)
    return (
      <Show when={enabled() && options.indicator}>
        <box paddingLeft={1} flexShrink={0}>
          <text fg={api.theme.current.textMuted}>{modeLabel(vim())}</text>
        </box>
      </Show>
    )
  }

  function ModeKeeper() {
    createEffect(() => {
      api.route.current.name
      vim().mode
      enabled()
      syncPromptMode()
    })
    return null
  }

  api.slots.register({
    order: 100,
    slots: {
      app() {
        return <ModeKeeper />
      },
      home_prompt_right() {
        return <Status />
      },
      session_prompt_right() {
        return <Status />
      },
    },
  })

  api.lifecycle.onDispose(() => {
    popPrompt()
    for (const timer of returnTimers) clearTimeout(timer)
    for (const item of appearances.keys()) restoreAppearance(item)
  })
}

export default {
  id: PLUGIN_ID,
  tui,
} satisfies TuiPluginModule & { id: string }
