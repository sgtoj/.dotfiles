import {
  graphemes,
  lineEnd,
  lineIndexAt,
  lineRange,
  lineStart,
  lineStarts,
  motionRange,
  nextGrapheme,
  normalCursor,
  resolveFind,
  resolveMotion,
  selectionRange,
  type Find,
  type Motion,
  type Range,
} from "./text"

export type TranscriptLine = {
  key: string
  text: string
  role: "user" | "assistant"
  kind: "speaker" | "text" | "reasoning" | "tool" | "file" | "separator"
  messageID: string
  partID?: string
}

export type TranscriptDocument = {
  lines: TranscriptLine[]
  text: string
  starts: number[]
}

export type TranscriptOptions = {
  reasoning?: boolean
  toolOutput?: boolean
}

type RecordValue = Record<string, unknown>

function record(value: unknown): RecordValue | undefined {
  return typeof value === "object" && value !== null && !Array.isArray(value) ? (value as RecordValue) : undefined
}

function text(value: unknown) {
  return typeof value === "string" ? value : undefined
}

function normalize(value: string) {
  return value.replace(/\r\n?/gu, "\n")
}

function addTextLines(
  target: TranscriptLine[],
  value: string,
  source: Omit<TranscriptLine, "key" | "text">,
  key: string,
) {
  normalize(value)
    .split("\n")
    .forEach((line, index) => target.push({ ...source, key: `${key}:${index}`, text: line }))
}

function stringify(value: unknown) {
  if (typeof value === "string") return value
  if (value === undefined) return ""
  try {
    return JSON.stringify(value, null, 2)
  } catch {
    return String(value)
  }
}

export function buildTranscript(
  input: ReadonlyArray<{ info: unknown; parts: ReadonlyArray<unknown> }>,
  options: TranscriptOptions = {},
): TranscriptDocument {
  const lines: TranscriptLine[] = []
  const messages = input
    .map((item) => ({ info: record(item.info), parts: item.parts }))
    .filter((item): item is { info: RecordValue; parts: ReadonlyArray<unknown> } => !!item.info && typeof item.info.id === "string")
    .toSorted((left, right) => {
      const leftTime = Number(record(left.info.time)?.created ?? 0)
      const rightTime = Number(record(right.info.time)?.created ?? 0)
      return leftTime - rightTime || String(left.info.id).localeCompare(String(right.info.id))
    })

  for (const message of messages) {
    const messageID = String(message.info.id)
    const role: TranscriptLine["role"] = message.info.role === "user" ? "user" : "assistant"
    lines.push({
      key: `${messageID}:speaker`,
      text: role === "user" ? "You" : "Assistant",
      role,
      kind: "speaker",
      messageID,
    })

    for (const rawPart of message.parts) {
      const part = record(rawPart)
      if (!part || typeof part.id !== "string" || typeof part.type !== "string") continue
      const partID = part.id
      const source = { role, messageID, partID }

      if (part.type === "text") {
        if (part.synthetic === true || part.ignored === true) continue
        const value = text(part.text)
        if (value !== undefined) addTextLines(lines, value, { ...source, kind: "text" }, partID)
        continue
      }

      if (part.type === "reasoning" && options.reasoning) {
        const value = text(part.text)
        if (value !== undefined) addTextLines(lines, value, { ...source, kind: "reasoning" }, partID)
        continue
      }

      if (part.type === "file") {
        lines.push({
          key: `${partID}:file`,
          text: `[file: ${text(part.filename) ?? text(part.mime) ?? "attachment"}]`,
          ...source,
          kind: "file",
        })
        continue
      }

      if (part.type === "tool") {
        const state = record(part.state)
        const status = text(state?.status) ?? "unknown"
        const name = text(part.tool) ?? "tool"
        lines.push({ key: `${partID}:tool`, text: `[tool: ${name} (${status})]`, ...source, kind: "tool" })
        if (options.toolOutput) {
          const output = status === "error" ? state?.error : state?.output
          const value = stringify(output)
          if (value) addTextLines(lines, value, { ...source, kind: "tool" }, `${partID}:output`)
        }
      }
    }

    lines.push({
      key: `${messageID}:separator`,
      text: "",
      role,
      kind: "separator",
      messageID,
    })
  }

  if (lines.at(-1)?.kind === "separator") lines.pop()
  const body = lines.map((line) => line.text).join("\n")
  return { lines, text: body, starts: lineStarts(body) }
}

export type CopyVisual = "character" | "line"

export type CopyState = {
  cursor: number
  preferredColumn?: number
  visual?: CopyVisual
  anchor?: number
  pending: "" | "g" | "f" | "F" | "t" | "T" | "y"
  count: string
  lastFind?: Find
  query: string
  matches: Range[]
  matchIndex: number
  searchDirection?: 1 | -1
}

export type CopyEffect =
  | { type: "exit" }
  | { type: "focus-prompt" }
  | { type: "search"; direction: 1 | -1 }
  | { type: "yank"; text: string; linewise: boolean }
  | { type: "bell" }

export type CopyStep = {
  state: CopyState
  effects: CopyEffect[]
}

export function initialCopyState(document: TranscriptDocument): CopyState {
  return {
    cursor: normalCursor(document.text, document.text.length),
    pending: "",
    count: "",
    query: "",
    matches: [],
    matchIndex: -1,
  }
}

function amount(state: CopyState) {
  const value = Number(state.count || "1")
  return Math.max(1, Math.min(Number.isSafeInteger(value) ? value : 1, 9999))
}

function reset(state: CopyState): CopyState {
  return { ...state, pending: "", count: "" }
}

function move(state: CopyState, document: TranscriptDocument, motion: Motion): CopyState {
  const result = resolveMotion(document.text, state.cursor, motion, amount(state), state.preferredColumn)
  return {
    ...reset(state),
    cursor: result.cursor,
    preferredColumn: motion === "j" || motion === "k" ? result.preferredColumn : undefined,
  }
}

function selectedRange(state: CopyState, document: TranscriptDocument): Range | undefined {
  if (!state.visual || state.anchor === undefined) return
  return selectionRange(document.text, state.anchor, state.cursor, state.visual === "line")
}

function yankRange(state: CopyState, document: TranscriptDocument, range: Range): CopyStep {
  const value = document.text.slice(range.start, range.end)
  return {
    state: { ...reset(state), visual: undefined, anchor: undefined, cursor: range.start },
    effects: [{ type: "yank", text: value, linewise: !!range.linewise }],
  }
}

function repeatSearch(state: CopyState, reverse: boolean): CopyState {
  if (!state.matches.length) return state
  const direction = (state.searchDirection ?? 1) * (reverse ? -1 : 1)
  let index = state.matchIndex
  if (index < 0) index = direction === 1 ? 0 : state.matches.length - 1
  else index = (index + direction + state.matches.length) % state.matches.length
  return { ...state, matchIndex: index, cursor: state.matches[index]!.start }
}

export function setCopySearch(state: CopyState, document: TranscriptDocument, query: string, direction: 1 | -1): CopyState {
  if (!query) return { ...state, query: "", matches: [], matchIndex: -1, searchDirection: direction }
  const sensitive = /\p{Lu}/u.test(query)
  const matches: Range[] = []
  if (sensitive) {
    let from = 0
    while (from <= document.text.length) {
      const index = document.text.indexOf(query, from)
      if (index < 0) break
      matches.push({ start: index, end: index + query.length })
      from = index + Math.max(1, query.length)
    }
  } else {
    const source = graphemes(document.text)
    const width = Math.max(1, graphemes(query).length)
    const collator = new Intl.Collator(undefined, { usage: "search", sensitivity: "base" })
    for (let index = 0; index < source.length; index++) {
      const start = source[index]!.index
      const end = source[index + width]?.index ?? document.text.length
      if (collator.compare(document.text.slice(start, end), query) === 0) matches.push({ start, end })
    }
  }
  if (!matches.length) return { ...state, query, matches, matchIndex: -1, searchDirection: direction }
  let matchIndex =
    direction === 1
      ? matches.findIndex((match) => match.start > state.cursor)
      : matches.findLastIndex((match) => match.start < state.cursor)
  if (matchIndex < 0) matchIndex = direction === 1 ? 0 : matches.length - 1
  return { ...state, query, matches, matchIndex, cursor: matches[matchIndex]!.start, searchDirection: direction }
}

export function handleCopyKey(state: CopyState, document: TranscriptDocument, key: string): CopyStep {
  const normalized = key === "left" ? "h" : key === "right" ? "l" : key === "up" ? "k" : key === "down" ? "j" : key

  if (state.pending === "g") {
    return normalized === "g"
      ? { state: move({ ...state, pending: "" }, document, "gg"), effects: [] }
      : { state: reset(state), effects: [{ type: "bell" }] }
  }

  if (state.pending === "f" || state.pending === "F" || state.pending === "t" || state.pending === "T") {
    const value = normalized === "space" ? " " : normalized.length === 1 ? normalized : undefined
    if (!value) return { state: reset(state), effects: [{ type: "bell" }] }
    const find: Find = {
      needle: value,
      direction: state.pending === "f" || state.pending === "t" ? 1 : -1,
      till: state.pending === "t" || state.pending === "T",
    }
    const result = resolveFind(document.text, state.cursor, find, amount(state))
    if (!result) return { state: reset(state), effects: [{ type: "bell" }] }
    return { state: { ...reset(state), cursor: result.cursor, lastFind: find }, effects: [] }
  }

  if (state.pending === "y") {
    if (normalized !== "y") return { state: reset(state), effects: [{ type: "bell" }] }
    return yankRange(state, document, lineRange(document.text, state.cursor, amount(state)))
  }

  if (/^[1-9]$/u.test(normalized) || (normalized === "0" && state.count)) {
    return { state: { ...state, count: (state.count + normalized).slice(0, 4) }, effects: [] }
  }

  if (normalized === "escape") {
    if (state.visual) return { state: { ...reset(state), visual: undefined, anchor: undefined }, effects: [] }
    return { state: reset(state), effects: [{ type: "exit" }] }
  }
  if (normalized === "q") return { state: reset(state), effects: [{ type: "exit" }] }
  if (normalized === "i") return { state: reset(state), effects: [{ type: "focus-prompt" }] }
  if (normalized === "/" || normalized === "?") {
    return { state: reset(state), effects: [{ type: "search", direction: normalized === "/" ? 1 : -1 }] }
  }
  if (normalized === "n" || normalized === "N") return { state: repeatSearch(reset(state), normalized === "N"), effects: [] }
  if (normalized === "g") return { state: { ...state, pending: "g" }, effects: [] }
  if (normalized === "f" || normalized === "F" || normalized === "t" || normalized === "T") {
    return { state: { ...state, pending: normalized }, effects: [] }
  }
  if ((normalized === ";" || normalized === ",") && state.lastFind) {
    const find = normalized === "," ? { ...state.lastFind, direction: (state.lastFind.direction * -1) as -1 | 1 } : state.lastFind
    const result = resolveFind(document.text, state.cursor, find, amount(state))
    if (!result) return { state: reset(state), effects: [{ type: "bell" }] }
    return { state: { ...reset(state), cursor: result.cursor }, effects: [] }
  }

  const motion = normalized as Motion
  if (["h", "j", "k", "l", "w", "W", "b", "B", "e", "E", "0", "^", "$", "G", "%", "{", "}"].includes(motion)) {
    return { state: move(state, document, motion), effects: [] }
  }

  if (normalized === "v" || normalized === "V") {
    const visual = normalized === "v" ? "character" : "line"
    if (state.visual === visual) return { state: { ...reset(state), visual: undefined, anchor: undefined }, effects: [] }
    return { state: { ...reset(state), visual, anchor: state.anchor ?? state.cursor }, effects: [] }
  }
  if (normalized === "o" && state.visual && state.anchor !== undefined) {
    return { state: { ...reset(state), anchor: state.cursor, cursor: state.anchor }, effects: [] }
  }
  if (normalized === "y") {
    const range = selectedRange(state, document)
    return range ? yankRange(state, document, range) : { state: { ...state, pending: "y" }, effects: [] }
  }
  if (normalized === "return") {
    const range = selectedRange(state, document)
    return range ? yankRange(state, document, range) : { state: reset(state), effects: [] }
  }

  return { state: reset(state), effects: [{ type: "bell" }] }
}

export function copySelection(state: CopyState, document: TranscriptDocument) {
  return selectedRange(state, document)
}

export function cursorPoint(state: CopyState, document: TranscriptDocument) {
  const line = lineIndexAt(document.text, state.cursor)
  const start = document.starts[line] ?? 0
  return {
    line,
    column: graphemes(document.text.slice(start, state.cursor)).length,
  }
}

export function offsetForPoint(document: TranscriptDocument, line: number, column: number) {
  const start = document.starts[Math.max(0, Math.min(document.starts.length - 1, line))] ?? 0
  const end = lineEnd(document.text, start)
  const list = graphemes(document.text.slice(start, end))
  return start + (list[Math.max(0, Math.min(list.length - 1, column))]?.index ?? 0)
}

export function copyStatus(state: CopyState) {
  if (state.pending) return state.pending
  if (state.count) return state.count
  if (state.visual === "character") return "-- VISUAL --"
  if (state.visual === "line") return "-- VISUAL LINE --"
  return "-- COPY --"
}

export function rangeContains(range: Range | undefined, offset: number) {
  return !!range && offset >= range.start && offset < range.end
}

export function currentSearchRange(state: CopyState) {
  return state.matchIndex >= 0 ? state.matches[state.matchIndex] : undefined
}

export function lineOffset(document: TranscriptDocument, line: number) {
  return document.starts[line] ?? document.text.length
}

export function nextLineOffset(document: TranscriptDocument, line: number) {
  return document.starts[line + 1] ?? document.text.length
}

export function cursorGraphemeEnd(document: TranscriptDocument, cursor: number) {
  return nextGrapheme(document.text, cursor)
}

export function copyMotionRange(document: TranscriptDocument, cursor: number, motion: Motion, count = 1) {
  return motionRange(document.text, cursor, resolveMotion(document.text, cursor, motion, count))
}
