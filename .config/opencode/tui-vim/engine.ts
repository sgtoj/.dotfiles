import {
  bracketObject,
  firstNonBlank,
  graphemes,
  lineEnd,
  lineIndexAt,
  lineRange,
  lineStart,
  lineStarts,
  motionRange,
  nextGrapheme,
  normalCursor,
  previousGrapheme,
  quoteObject,
  resolveFind,
  resolveMotion,
  selectionRange,
  wordObject,
  type Find,
  type Motion,
  type Range,
} from "./text"

export type VimMode = "insert" | "normal" | "replace" | "visual" | "visual-line"
export type Operator = "delete" | "change" | "yank"

export type Frame = {
  text: string
  cursor: number
}

export type Register = {
  text: string
  linewise: boolean
} | null

type Snapshot = Frame

type ChangeRecipe = {
  keys: string[]
  inserted?: string
}

type InsertTransaction = {
  undo: Snapshot
  base: Snapshot
  keys: string[]
}

type OperatorPending = {
  kind: "operator"
  operator: Operator
  count: number
  afterCount: string
  prefix?: "g" | "i" | "a"
  keys: string[]
}

type Pending =
  | { kind: "g"; count: number; keys: string[] }
  | { kind: "find"; find: Omit<Find, "needle">; count: number; keys: string[] }
  | { kind: "replace"; count: number; keys: string[] }
  | OperatorPending
  | null

export type VimState = {
  mode: VimMode
  count: string
  pending: Pending
  preferredColumn?: number
  visualAnchor?: number
  register: Register
  lastFind?: Find
  undo: Snapshot[]
  redo: Snapshot[]
  insert?: InsertTransaction
  lastChange?: ChangeRecipe
  replaying: boolean
}

export type VimEffect =
  | { type: "submit" }
  | { type: "palette" }
  | { type: "bell" }

export type VimStep = {
  state: VimState
  frame: Frame
  handled: boolean
  effects: VimEffect[]
}

const motions = new Set<Motion>(["h", "j", "k", "l", "w", "W", "b", "B", "e", "E", "0", "^", "$", "G", "%", "{", "}"])

export function initialState(mode: VimMode = "insert"): VimState {
  return {
    mode,
    count: "",
    pending: null,
    register: null,
    undo: [],
    redo: [],
    replaying: false,
  }
}

export function trackInsert(state: VimState, frame: Frame, keys: string[] = ["i"]): VimState {
  if (state.mode !== "insert" || state.insert) return state
  return {
    ...state,
    insert: {
      undo: snapshot(frame),
      base: snapshot(frame),
      keys,
    },
  }
}

function snapshot(frame: Frame): Snapshot {
  return { text: frame.text, cursor: frame.cursor }
}

function sameFrame(left: Frame, right: Frame) {
  return left.text === right.text && left.cursor === right.cursor
}

function resetCommand(state: VimState): VimState {
  return { ...state, count: "", pending: null }
}

function countValue(value: string, fallback = 1) {
  if (!value) return fallback
  const number = Number(value)
  return Math.max(1, Math.min(Number.isSafeInteger(number) ? number : fallback, 9999))
}

function commandKeys(state: VimState, key: string) {
  return [...state.count.split(""), key]
}

function pushUndo(state: VimState, before: Snapshot, after: Snapshot) {
  if (sameFrame(before, after)) return state
  return { ...state, undo: [...state.undo, before], redo: [] }
}

function recordChange(state: VimState, keys: string[], inserted?: string) {
  if (state.replaying) return state
  return { ...state, lastChange: { keys, inserted } }
}

function replaceRange(frame: Frame, range: Range, value: string, cursor = range.start): Frame {
  return {
    text: frame.text.slice(0, range.start) + value + frame.text.slice(range.end),
    cursor,
  }
}

function deleteRange(frame: Frame, range: Range) {
  const next = replaceRange(frame, range, "")
  return { ...next, cursor: normalCursor(next.text, next.cursor) }
}

function normalizeLineRegister(value: string) {
  return value.replace(/^\n/u, "").replace(/\n$/u, "")
}

function registerFor(frame: Frame, range: Range): Register {
  const value = frame.text.slice(range.start, range.end)
  return {
    text: range.linewise ? normalizeLineRegister(value) : value,
    linewise: !!range.linewise,
  }
}

function lineChangeRange(text: string, cursor: number, count: number): Range {
  const starts = lineStarts(text)
  const row = lineIndexAt(text, cursor)
  const last = Math.min(starts.length - 1, row + Math.max(1, count) - 1)
  return {
    start: starts[row] ?? 0,
    end: lineEnd(text, starts[last] ?? 0),
    linewise: true,
  }
}

function startInsert(
  state: VimState,
  before: Frame,
  frame: Frame,
  keys: string[],
  mode: "insert" | "replace" = "insert",
): VimStep {
  return {
    state: {
      ...resetCommand(state),
      mode,
      visualAnchor: undefined,
      insert: { undo: snapshot(before), base: snapshot(frame), keys },
    },
    frame,
    handled: true,
    effects: [],
  }
}

function insertedText(base: string, value: string) {
  let prefix = 0
  while (prefix < base.length && prefix < value.length && base[prefix] === value[prefix]) prefix++
  let suffix = 0
  while (
    suffix < base.length - prefix &&
    suffix < value.length - prefix &&
    base[base.length - suffix - 1] === value[value.length - suffix - 1]
  )
    suffix++
  if (base.length - prefix - suffix !== 0) return
  return value.slice(prefix, value.length - suffix)
}

function leaveInsert(state: VimState, frame: Frame): VimStep {
  let next: VimState = { ...resetCommand(state), mode: "normal", insert: undefined }
  if (state.insert && state.insert.undo.text !== frame.text) {
    next = pushUndo(next, state.insert.undo, snapshot(frame))
    const text = insertedText(state.insert.base.text, frame.text)
    if (text !== undefined) next = recordChange(next, state.insert.keys, text)
    else if (!state.replaying) next = { ...next, lastChange: undefined }
  }
  const cursor = frame.cursor > lineStart(frame.text, frame.cursor)
    ? previousGrapheme(frame.text, frame.cursor)
    : frame.cursor
  return {
    state: next,
    frame: { ...frame, cursor: normalCursor(frame.text, cursor) },
    handled: true,
    effects: [],
  }
}

function operateRange(
  state: VimState,
  frame: Frame,
  operator: Operator,
  range: Range,
  keys: string[],
): VimStep {
  if (range.end <= range.start) return invalid(state, frame)
  const register = registerFor(frame, range)
  const visual = state.mode === "visual" || state.mode === "visual-line"
  if (operator === "yank") {
    return {
      state: { ...resetCommand(state), mode: "normal", visualAnchor: undefined, register },
      frame: { ...frame, cursor: range.start },
      handled: true,
      effects: [],
    }
  }
  const before = snapshot(frame)
  if (operator === "change") {
    const target = range.linewise && frame.text[range.end - 1] === "\n"
      ? { ...range, end: range.end - 1 }
      : range
    const changed = replaceRange(frame, target, "", target.start)
    const started = startInsert(
      { ...state, register, ...(visual ? { lastChange: undefined } : {}) },
      before,
      changed,
      visual ? [] : keys,
    )
    return started
  }
  const target = range.linewise && range.end === frame.text.length && range.start > 0
    ? { ...range, start: range.start - 1 }
    : range
  const changed = deleteRange(frame, target)
  let next = pushUndo({ ...resetCommand(state), mode: "normal" as const, visualAnchor: undefined, register }, before, changed)
  next = visual ? { ...next, lastChange: undefined } : recordChange(next, keys)
  return { state: next, frame: changed, handled: true, effects: [] }
}

function applyMotion(state: VimState, frame: Frame, motion: Motion, count: number): VimStep {
  const result = resolveMotion(frame.text, frame.cursor, motion, count, state.preferredColumn)
  return {
    state: {
      ...resetCommand(state),
      preferredColumn: motion === "j" || motion === "k" ? result.preferredColumn : undefined,
    },
    frame: { ...frame, cursor: result.cursor },
    handled: true,
    effects: [],
  }
}

function applyOperatorMotion(
  state: VimState,
  frame: Frame,
  pending: OperatorPending,
  motion: Motion,
  keys: string[],
): VimStep {
  const after = countValue(pending.afterCount)
  const count = pending.count * after
  const actual = pending.operator === "change" && motion === "w" && /\S/u.test(frame.text[frame.cursor] ?? "") ? "e" : motion
  const result = resolveMotion(frame.text, frame.cursor, actual, count, state.preferredColumn)
  if (result.failed) return invalid(state, frame)
  const range = motionRange(frame.text, frame.cursor, result)
  return range.end > range.start ? operateRange(state, frame, pending.operator, range, keys) : invalid(state, frame)
}

function characterFromKey(key: string) {
  if (key === "space") return " "
  if (key === "return") return "\n"
  return graphemes(key).length === 1 ? key : undefined
}

function textObjectRange(frame: Frame, prefix: "i" | "a", key: string, count = 1): Range | undefined {
  const around = prefix === "a"
  if (key === "w" || key === "W") {
    const big = key === "W"
    const first = wordObject(frame.text, frame.cursor, around, big)
    if (!first) return
    let end = first.end
    for (let index = 1; index < count; index++) {
      const cursor = resolveMotion(frame.text, end, big ? "W" : "w").cursor
      const next = wordObject(frame.text, cursor, around, big)
      if (!next) break
      end = Math.max(end, next.end)
    }
    return { start: first.start, end }
  }
  if (key === '"' || key === "'" || key === "`") return quoteObject(frame.text, frame.cursor, key, around)
  const pairs: Record<string, string> = {
    "(": "()",
    ")": "()",
    b: "()",
    "[": "[]",
    "]": "[]",
    "{": "{}",
    "}": "{}",
    B: "{}",
    "<": "<>",
    ">": "<>",
  }
  return pairs[key] ? bracketObject(frame.text, frame.cursor, pairs[key]!, around) : undefined
}

function invalid(state: VimState, frame: Frame): VimStep {
  return { state: resetCommand(state), frame, handled: true, effects: [{ type: "bell" }] }
}

function handleOperator(state: VimState, frame: Frame, key: string, pending: OperatorPending): VimStep {
  if (/^[0-9]$/u.test(key) && (key !== "0" || pending.afterCount)) {
    return {
      state: { ...state, pending: { ...pending, afterCount: (pending.afterCount + key).slice(0, 4), keys: [...pending.keys, key] } },
      frame,
      handled: true,
      effects: [],
    }
  }

  if (pending.prefix === "i" || pending.prefix === "a") {
    const range = textObjectRange(frame, pending.prefix, key, pending.count * countValue(pending.afterCount))
    if (!range) return invalid(state, frame)
    return operateRange(state, frame, pending.operator, range, [...pending.keys, key])
  }

  if (pending.prefix === "g") {
    if (key !== "g") return invalid(state, frame)
    return applyOperatorMotion(state, frame, pending, "gg", [...pending.keys, key])
  }

  if (key === pending.keys.find((item) => item === "d" || item === "c" || item === "y")) {
    const count = pending.count * countValue(pending.afterCount)
    const range = pending.operator === "change" ? lineChangeRange(frame.text, frame.cursor, count) : lineRange(frame.text, frame.cursor, count)
    return operateRange(state, frame, pending.operator, range, [...pending.keys, key])
  }

  if (key === "i" || key === "a") {
    return {
      state: { ...state, pending: { ...pending, prefix: key, keys: [...pending.keys, key] } },
      frame,
      handled: true,
      effects: [],
    }
  }

  if (key === "g") {
    return {
      state: { ...state, pending: { ...pending, prefix: "g", keys: [...pending.keys, key] } },
      frame,
      handled: true,
      effects: [],
    }
  }

  if (key === "f" || key === "F" || key === "t" || key === "T") {
    const find: Omit<Find, "needle"> = { direction: key === "f" || key === "t" ? 1 : -1, till: key === "t" || key === "T" }
    return {
      state: { ...state, pending: { ...pending, prefix: undefined, keys: [...pending.keys, key, `find:${key}`] } as OperatorPending },
      frame,
      handled: true,
      effects: [],
    }
  }

  if (motions.has(key as Motion)) return applyOperatorMotion(state, frame, pending, key as Motion, [...pending.keys, key])
  return invalid(state, frame)
}

function replaceCharacters(state: VimState, frame: Frame, value: string, count: number, keys: string[]): VimStep {
  let end = frame.cursor
  const limit = lineEnd(frame.text, frame.cursor)
  for (let index = 0; index < count; index++) {
    const next = nextGrapheme(frame.text, end)
    if (next > limit || next === end) return invalid(state, frame)
    end = next
  }
  const before = snapshot(frame)
  const text = value.repeat(count)
  const changed = replaceRange(frame, { start: frame.cursor, end }, text, frame.cursor + Math.max(0, text.length - value.length))
  let next = pushUndo(resetCommand(state), before, changed)
  next = recordChange(next, keys)
  return { state: next, frame: changed, handled: true, effects: [] }
}

function joinLines(state: VimState, frame: Frame, count: number, keys: string[]): VimStep {
  const before = snapshot(frame)
  let text = frame.text
  let cursor = frame.cursor
  const joins = count === 1 ? 1 : count - 1
  for (let index = 0; index < joins; index++) {
    const end = lineEnd(text, cursor)
    if (end >= text.length) break
    const next = text.slice(end + 1).match(/^[^\S\n]*/u)?.[0].length ?? 0
    text = text.slice(0, end).replace(/[^\S\n]+$/u, "") + " " + text.slice(end + 1 + next)
    cursor = end
  }
  const changed = { text, cursor }
  let next = pushUndo(resetCommand(state), before, changed)
  next = recordChange(next, keys)
  return { state: next, frame: changed, handled: true, effects: [] }
}

function toggleCase(state: VimState, frame: Frame, count: number, keys: string[]): VimStep {
  const before = snapshot(frame)
  let cursor = frame.cursor
  let end = cursor
  let value = ""
  for (let index = 0; index < count && end < frame.text.length; index++) {
    const next = nextGrapheme(frame.text, end)
    const char = frame.text.slice(end, next)
    value += char === char.toUpperCase() ? char.toLowerCase() : char.toUpperCase()
    end = next
  }
  if (end === cursor) return invalid(state, frame)
  const changed = replaceRange(frame, { start: cursor, end }, value, Math.min(frame.text.length, end))
  changed.cursor = normalCursor(changed.text, changed.cursor)
  let next = pushUndo(resetCommand(state), before, changed)
  next = recordChange(next, keys)
  return { state: next, frame: changed, handled: true, effects: [] }
}

function put(state: VimState, frame: Frame, before: boolean, count: number, keys: string[]): VimStep {
  if (!state.register) return invalid(state, frame)
  const original = snapshot(frame)
  let changed: Frame
  if (state.register.linewise) {
    const value = Array.from({ length: count }, () => state.register!.text).join("\n")
    if (before) {
      const at = lineStart(frame.text, frame.cursor)
      changed = replaceRange(frame, { start: at, end: at }, `${value}\n`, at)
    } else {
      const end = lineEnd(frame.text, frame.cursor)
      if (end < frame.text.length) changed = replaceRange(frame, { start: end + 1, end: end + 1 }, `${value}\n`, end + 1)
      else changed = replaceRange(frame, { start: end, end }, `\n${value}`, end + 1)
    }
  } else {
    const at = before ? frame.cursor : nextGrapheme(frame.text, frame.cursor)
    const value = state.register.text.repeat(count)
    const insertedEnd = at + value.length
    changed = replaceRange(frame, { start: at, end: at }, value, value ? previousGrapheme(frame.text.slice(0, at) + value + frame.text.slice(at), insertedEnd) : at)
  }
  let next = pushUndo(resetCommand(state), original, changed)
  next = recordChange(next, keys)
  return { state: next, frame: changed, handled: true, effects: [] }
}

function undo(state: VimState, frame: Frame, redo: boolean): VimStep {
  const source = redo ? state.redo : state.undo
  const target = source.at(-1)
  if (!target) return invalid(state, frame)
  return {
    state: redo
      ? { ...resetCommand(state), undo: [...state.undo, snapshot(frame)], redo: state.redo.slice(0, -1) }
      : { ...resetCommand(state), undo: state.undo.slice(0, -1), redo: [...state.redo, snapshot(frame)] },
    frame: snapshot(target),
    handled: true,
    effects: [],
  }
}

function repeat(state: VimState, frame: Frame): VimStep {
  const recipe = state.lastChange
  if (!recipe) return invalid(state, frame)
  let step: VimStep = { state: { ...resetCommand(state), replaying: true }, frame, handled: true, effects: [] }
  for (const key of recipe.keys) step = handleKey(step.state, step.frame, key)
  if ((step.state.mode === "insert" || step.state.mode === "replace") && recipe.inserted !== undefined) {
    const at = step.frame.cursor
    const inserted = replaceRange(step.frame, { start: at, end: at }, recipe.inserted, at + recipe.inserted.length)
    step = handleKey(step.state, inserted, "escape")
  }
  return { ...step, state: { ...step.state, replaying: false, lastChange: recipe } }
}

function handleVisual(state: VimState, frame: Frame, key: string): VimStep {
  const anchor = state.visualAnchor ?? frame.cursor
  if (key === "escape" || (key === "v" && state.mode === "visual") || (key === "V" && state.mode === "visual-line")) {
    return { state: { ...resetCommand(state), mode: "normal", visualAnchor: undefined }, frame, handled: true, effects: [] }
  }
  if (key === "v" || key === "V") {
    return { state: { ...state, mode: key === "v" ? "visual" : "visual-line" }, frame, handled: true, effects: [] }
  }
  if (key === "o") {
    return { state: { ...state, visualAnchor: frame.cursor }, frame: { ...frame, cursor: anchor }, handled: true, effects: [] }
  }
  const operator = key === "d" || key === "x" ? "delete" : key === "c" || key === "s" ? "change" : key === "y" ? "yank" : undefined
  if (operator) {
    const range = selectionRange(frame.text, anchor, frame.cursor, state.mode === "visual-line")
    return operateRange(state, frame, operator, range, [key])
  }
  if (motions.has(key as Motion)) {
    const count = countValue(state.count)
    const result = resolveMotion(frame.text, frame.cursor, key as Motion, count, state.preferredColumn)
    return {
      state: { ...state, count: "", preferredColumn: key === "j" || key === "k" ? result.preferredColumn : undefined },
      frame: { ...frame, cursor: result.cursor },
      handled: true,
      effects: [],
    }
  }
  if (/^[1-9]$/u.test(key) || (/^[0-9]$/u.test(key) && state.count)) {
    return { state: { ...state, count: (state.count + key).slice(0, 4) }, frame, handled: true, effects: [] }
  }
  return invalid(state, frame)
}

function handlePending(state: VimState, frame: Frame, key: string): VimStep | undefined {
  const pending = state.pending
  if (!pending) return
  if (pending.kind === "operator") {
    const marker = pending.keys.at(-1)
    if (marker?.startsWith("find:")) {
      const value = characterFromKey(key)
      if (!value) return invalid(state, frame)
      const command = marker.slice(5)
      const find: Find = {
        needle: value,
        direction: command === "f" || command === "t" ? 1 : -1,
        till: command === "t" || command === "T",
      }
      const result = resolveFind(frame.text, frame.cursor, find, pending.count * countValue(pending.afterCount))
      if (!result) return invalid(state, frame)
      const step = operateRange(state, frame, pending.operator, motionRange(frame.text, frame.cursor, result), [...pending.keys.slice(0, -1), key])
      return { ...step, state: { ...step.state, lastFind: find } }
    }
    return handleOperator(state, frame, key, pending)
  }
  if (pending.kind === "g") {
    if (key !== "g") return invalid(state, frame)
    return applyMotion(state, frame, "gg", pending.count)
  }
  if (pending.kind === "find") {
    const value = characterFromKey(key)
    if (!value) return invalid(state, frame)
    const find: Find = { ...pending.find, needle: value }
    const result = resolveFind(frame.text, frame.cursor, find, pending.count)
    if (!result) return invalid(state, frame)
    return {
      state: { ...resetCommand(state), lastFind: find },
      frame: { ...frame, cursor: result.cursor },
      handled: true,
      effects: [],
    }
  }
  if (pending.kind === "replace") {
    const value = characterFromKey(key)
    return value ? replaceCharacters(state, frame, value, pending.count, [...pending.keys, key]) : invalid(state, frame)
  }
}

export function handleKey(state: VimState, frame: Frame, key: string): VimStep {
  const normalized = key === "left" ? "h" : key === "right" ? "l" : key === "up" ? "k" : key === "down" ? "j" : key

  if (state.mode === "insert") {
    if (normalized === "escape") return leaveInsert(state, frame)
    return { state, frame, handled: false, effects: [] }
  }

  if (state.mode === "replace") {
    if (normalized === "escape") return leaveInsert(state, frame)
    if (normalized === "backspace") {
      const start = previousGrapheme(frame.text, frame.cursor)
      return { state, frame: replaceRange(frame, { start, end: frame.cursor }, "", start), handled: true, effects: [] }
    }
    const value = characterFromKey(normalized)
    if (!value) return { state, frame, handled: true, effects: [] }
    const limit = lineEnd(frame.text, frame.cursor)
    const end = frame.cursor < limit ? nextGrapheme(frame.text, frame.cursor) : frame.cursor
    return { state, frame: replaceRange(frame, { start: frame.cursor, end }, value, frame.cursor + value.length), handled: true, effects: [] }
  }

  if (state.mode === "visual" || state.mode === "visual-line") return handleVisual(state, frame, normalized)

  const pending = handlePending(state, frame, normalized)
  if (pending) return pending

  if (normalized === "escape") {
    return { state: resetCommand(state), frame, handled: true, effects: [] }
  }

  if (/^[1-9]$/u.test(normalized) || (normalized === "0" && state.count)) {
    return { state: { ...state, count: (state.count + normalized).slice(0, 4) }, frame, handled: true, effects: [] }
  }

  const count = countValue(state.count)
  const keys = commandKeys(state, normalized)

  if (motions.has(normalized as Motion)) return applyMotion(state, frame, normalized as Motion, count)
  if (normalized === "g") {
    return { state: { ...state, pending: { kind: "g", count, keys }, count: "" }, frame, handled: true, effects: [] }
  }
  if (normalized === "f" || normalized === "F" || normalized === "t" || normalized === "T") {
    return {
      state: {
        ...state,
        count: "",
        pending: {
          kind: "find",
          find: { direction: normalized === "f" || normalized === "t" ? 1 : -1, till: normalized === "t" || normalized === "T" },
          count,
          keys,
        },
      },
      frame,
      handled: true,
      effects: [],
    }
  }
  if ((normalized === ";" || normalized === ",") && state.lastFind) {
    const find = normalized === "," ? { ...state.lastFind, direction: (state.lastFind.direction * -1) as -1 | 1 } : state.lastFind
    const result = resolveFind(frame.text, frame.cursor, find, count)
    if (!result) return invalid(state, frame)
    return { state: resetCommand(state), frame: { ...frame, cursor: result.cursor }, handled: true, effects: [] }
  }
  if (normalized === "d" || normalized === "c" || normalized === "y") {
    const operator: Operator = normalized === "d" ? "delete" : normalized === "c" ? "change" : "yank"
    return {
      state: { ...state, count: "", pending: { kind: "operator", operator, count, afterCount: "", keys } },
      frame,
      handled: true,
      effects: [],
    }
  }

  if (normalized === "i") return startInsert(state, frame, frame, keys)
  if (normalized === "a") return startInsert(state, frame, { ...frame, cursor: nextGrapheme(frame.text, frame.cursor) }, keys)
  if (normalized === "I") return startInsert(state, frame, { ...frame, cursor: firstNonBlank(frame.text, frame.cursor) }, keys)
  if (normalized === "A") return startInsert(state, frame, { ...frame, cursor: lineEnd(frame.text, frame.cursor) }, keys)
  if (normalized === "o") {
    const at = lineEnd(frame.text, frame.cursor)
    const opened = replaceRange(frame, { start: at, end: at }, "\n", at + 1)
    return startInsert(state, frame, opened, keys)
  }
  if (normalized === "O") {
    const at = lineStart(frame.text, frame.cursor)
    const opened = replaceRange(frame, { start: at, end: at }, "\n", at)
    return startInsert(state, frame, opened, keys)
  }
  if (normalized === "R") return startInsert(state, frame, frame, keys, "replace")

  if (normalized === "x") {
    let end = frame.cursor
    const limit = lineEnd(frame.text, frame.cursor)
    for (let index = 0; index < count; index++) end = Math.min(limit, nextGrapheme(frame.text, end))
    return operateRange(state, frame, "delete", { start: frame.cursor, end }, keys)
  }
  if (normalized === "X") {
    let start = frame.cursor
    const limit = lineStart(frame.text, frame.cursor)
    for (let index = 0; index < count; index++) start = Math.max(limit, previousGrapheme(frame.text, start))
    return operateRange(state, frame, "delete", { start, end: frame.cursor }, keys)
  }
  if (normalized === "s") {
    let end = frame.cursor
    const limit = lineEnd(frame.text, frame.cursor)
    for (let index = 0; index < count; index++) end = Math.min(limit, nextGrapheme(frame.text, end))
    return operateRange(state, frame, "change", { start: frame.cursor, end }, keys)
  }
  if (normalized === "S") return operateRange(state, frame, "change", lineChangeRange(frame.text, frame.cursor, count), keys)
  if (normalized === "D") {
    return operateRange(state, frame, "delete", { start: frame.cursor, end: lineEnd(frame.text, frame.cursor) }, keys)
  }
  if (normalized === "C") {
    return operateRange(state, frame, "change", { start: frame.cursor, end: lineEnd(frame.text, frame.cursor) }, keys)
  }
  if (normalized === "r") {
    return { state: { ...state, count: "", pending: { kind: "replace", count, keys } }, frame, handled: true, effects: [] }
  }
  if (normalized === "J") return joinLines(state, frame, count, keys)
  if (normalized === "~") return toggleCase(state, frame, count, keys)
  if (normalized === "Y") return operateRange(state, frame, "yank", lineRange(frame.text, frame.cursor, count), keys)
  if (normalized === "p" || normalized === "P") return put(state, frame, normalized === "P", count, keys)
  if (normalized === "u") return undo(state, frame, false)
  if (normalized === "ctrl+r") return undo(state, frame, true)
  if (normalized === ".") return repeat(state, frame)
  if (normalized === "v" || normalized === "V") {
    return {
      state: { ...resetCommand(state), mode: normalized === "v" ? "visual" : "visual-line", visualAnchor: frame.cursor },
      frame,
      handled: true,
      effects: [],
    }
  }
  if (normalized === ":") {
    return { state: resetCommand(state), frame, handled: true, effects: [{ type: "palette" }] }
  }
  if (normalized === "return") {
    return { state: resetCommand(state), frame, handled: true, effects: [{ type: "submit" }] }
  }

  return invalid(state, frame)
}

export function pendingLabel(state: VimState) {
  if (state.count) return state.count
  const pending = state.pending
  if (!pending) return ""
  if (pending.kind === "g") return "g"
  if (pending.kind === "find") return pending.find.direction === 1 ? (pending.find.till ? "t" : "f") : pending.find.till ? "T" : "F"
  if (pending.kind === "replace") return "r"
  const op = pending.operator === "delete" ? "d" : pending.operator === "change" ? "c" : "y"
  return `${op}${pending.afterCount}${pending.prefix ?? ""}`
}

export function modeLabel(state: VimState) {
  const pending = pendingLabel(state)
  if (pending) return pending
  if (state.mode === "insert") return "-- INSERT --"
  if (state.mode === "replace") return "-- REPLACE --"
  if (state.mode === "visual") return "-- VISUAL --"
  if (state.mode === "visual-line") return "-- VISUAL LINE --"
  return "-- NORMAL --"
}

export function currentSelection(state: VimState, frame: Frame) {
  if ((state.mode !== "visual" && state.mode !== "visual-line") || state.visualAnchor === undefined) return
  return selectionRange(frame.text, state.visualAnchor, frame.cursor, state.mode === "visual-line")
}
