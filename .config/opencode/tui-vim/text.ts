export type Direction = -1 | 1

export type Find = {
  needle: string
  direction: Direction
  till: boolean
}

export type Motion =
  | "h"
  | "j"
  | "k"
  | "l"
  | "w"
  | "W"
  | "b"
  | "B"
  | "e"
  | "E"
  | "0"
  | "^"
  | "$"
  | "gg"
  | "G"
  | "%"
  | "{"
  | "}"

export type MotionResult = {
  cursor: number
  linewise?: boolean
  inclusive?: boolean
  preferredColumn?: number
  failed?: boolean
}

export type Range = {
  start: number
  end: number
  linewise?: boolean
}

const graphemeSegmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" })

export function graphemes(text: string): { segment: string; index: number }[] {
  return Array.from(graphemeSegmenter.segment(text), (item) => ({ segment: item.segment, index: item.index }))
}

export function clampCursor(text: string, cursor: number) {
  if (!text) return 0
  const value = Math.max(0, Math.min(cursor, text.length))
  if (value === text.length) return value
  const list = graphemes(text)
  let result = 0
  for (const item of list) {
    if (item.index > value) break
    result = item.index
  }
  return result
}

export function previousGrapheme(text: string, cursor: number) {
  const value = clampCursor(text, cursor)
  let result = 0
  for (const item of graphemes(text)) {
    if (item.index >= value) break
    result = item.index
  }
  return result
}

export function nextGrapheme(text: string, cursor: number) {
  const value = clampCursor(text, cursor)
  const list = graphemes(text)
  const current = list.findIndex((item) => item.index === value)
  if (current === -1 || current === list.length - 1) return text.length
  return list[current + 1]!.index
}

export function lineStarts(text: string) {
  const result = [0]
  for (let index = 0; index < text.length; index++) {
    if (text[index] === "\n") result.push(index + 1)
  }
  return result
}

export function lineIndexAt(text: string, cursor: number) {
  const starts = lineStarts(text)
  const value = Math.max(0, Math.min(cursor, text.length))
  let result = 0
  for (let index = 1; index < starts.length; index++) {
    if (starts[index]! > value) break
    result = index
  }
  return result
}

export function lineStart(text: string, cursor: number) {
  return lineStarts(text)[lineIndexAt(text, cursor)] ?? 0
}

export function lineEnd(text: string, cursor: number) {
  const newline = text.indexOf("\n", lineStart(text, cursor))
  return newline === -1 ? text.length : newline
}

export function firstNonBlank(text: string, cursor: number) {
  const start = lineStart(text, cursor)
  const end = lineEnd(text, cursor)
  const match = text.slice(start, end).search(/\S/u)
  return match === -1 ? start : start + match
}

export function lineRange(text: string, cursor: number, count = 1): Range {
  const starts = lineStarts(text)
  const row = lineIndexAt(text, cursor)
  const last = Math.min(starts.length - 1, row + Math.max(1, count) - 1)
  const start = starts[row] ?? 0
  const next = starts[last + 1]
  if (next !== undefined) return { start, end: next, linewise: true }
  return { start, end: text.length, linewise: true }
}

function graphemeColumn(text: string, start: number, cursor: number) {
  return graphemes(text.slice(start, cursor)).length
}

function offsetAtColumn(text: string, start: number, end: number, column: number) {
  const list = graphemes(text.slice(start, end))
  if (!list.length) return start
  const item = list[Math.max(0, Math.min(column, list.length - 1))]
  return start + (item?.index ?? 0)
}

function charClass(segment: string, big: boolean) {
  if (/^\s$/u.test(segment)) return 0
  if (big) return 1
  if (/^[\p{L}\p{N}_]\p{M}*$/u.test(segment)) return 1
  return 2
}

function graphemeEntries(text: string) {
  return graphemes(text).map((item, index, list) => ({
    ...item,
    end: list[index + 1]?.index ?? text.length,
  }))
}

function entryAt(text: string, cursor: number) {
  const list = graphemeEntries(text)
  if (!list.length) return { list, index: -1 }
  const value = clampCursor(text, Math.min(cursor, Math.max(0, text.length - 1)))
  let index = list.findIndex((item) => item.index === value)
  if (index === -1) index = list.findLastIndex((item) => item.index <= value)
  return { list, index: Math.max(0, index) }
}

function wordNext(text: string, cursor: number, count: number, big: boolean) {
  const { list, index: initial } = entryAt(text, cursor)
  if (!list.length) return 0
  let index = initial
  for (let iteration = 0; iteration < count; iteration++) {
    const current = charClass(list[index]!.segment, big)
    if (current !== 0) {
      while (index < list.length && charClass(list[index]!.segment, big) === current) index++
    }
    while (index < list.length && charClass(list[index]!.segment, big) === 0) index++
    if (index >= list.length) return text.length
  }
  return list[index]?.index ?? text.length
}

function wordPrevious(text: string, cursor: number, count: number, big: boolean) {
  const { list } = entryAt(text, cursor)
  if (!list.length) return 0
  let index = list.findLastIndex((item) => item.index < cursor)
  if (index < 0) return 0
  for (let iteration = 0; iteration < count; iteration++) {
    while (index > 0 && charClass(list[index]!.segment, big) === 0) index--
    const current = charClass(list[index]!.segment, big)
    while (index > 0 && charClass(list[index - 1]!.segment, big) === current) index--
    if (iteration < count - 1) index--
    if (index < 0) return 0
  }
  return list[index]?.index ?? 0
}

function wordEnd(text: string, cursor: number, count: number, big: boolean) {
  const { list, index: initial } = entryAt(text, cursor)
  if (!list.length) return 0
  let index = initial
  for (let iteration = 0; iteration < count; iteration++) {
    const currentClass = charClass(list[index]!.segment, big)
    const atClassEnd = currentClass !== 0 && (index + 1 >= list.length || charClass(list[index + 1]!.segment, big) !== currentClass)
    if (iteration > 0 || currentClass === 0 || atClassEnd) {
      index++
      while (index < list.length && charClass(list[index]!.segment, big) === 0) index++
    }
    if (index >= list.length) return list.at(-1)!.index
    const current = charClass(list[index]!.segment, big)
    while (index + 1 < list.length && charClass(list[index + 1]!.segment, big) === current) index++
  }
  return list[index]?.index ?? text.length
}

function vertical(text: string, cursor: number, delta: number, preferred?: number): MotionResult {
  const starts = lineStarts(text)
  const row = lineIndexAt(text, cursor)
  const target = Math.max(0, Math.min(starts.length - 1, row + delta))
  const column = preferred ?? graphemeColumn(text, starts[row] ?? 0, Math.min(cursor, lineEnd(text, cursor)))
  const start = starts[target] ?? 0
  const end = lineEnd(text, start)
  return { cursor: offsetAtColumn(text, start, end, column), preferredColumn: column, linewise: true }
}

function matchingBracket(text: string, cursor: number): number | undefined {
  const pairs: Record<string, string> = { "(": ")", "[": "]", "{": "}", "<": ">" }
  const reverse: Record<string, string> = Object.fromEntries(Object.entries(pairs).map(([left, right]) => [right, left]))
  let at = clampCursor(text, cursor)
  let char = text[at]
  if (!pairs[char ?? ""] && !reverse[char ?? ""]) {
    const end = lineEnd(text, cursor)
    while (at < end && !pairs[text[at] ?? ""] && !reverse[text[at] ?? ""]) at++
    char = text[at]
  }
  if (!char) return
  const direction: Direction = pairs[char] ? 1 : -1
  const open = direction === 1 ? char : reverse[char]!
  const close = pairs[open]!
  let depth = 0
  for (let index = at; index >= 0 && index < text.length; index += direction) {
    if (text[index] === open) depth += direction
    if (text[index] === close) depth -= direction
    if (depth === 0 && index !== at) return index
  }
  return
}

function paragraph(text: string, cursor: number, direction: Direction, count: number) {
  const starts = lineStarts(text)
  let row = lineIndexAt(text, cursor)
  for (let iteration = 0; iteration < count; iteration++) {
    row += direction
    while (row > 0 && row < starts.length - 1) {
      const value = text.slice(starts[row], lineEnd(text, starts[row])).trim()
      if (!value) break
      row += direction
    }
  }
  return starts[Math.max(0, Math.min(starts.length - 1, row))] ?? cursor
}

export function resolveMotion(
  text: string,
  cursor: number,
  motion: Motion,
  count = 1,
  preferredColumn?: number,
): MotionResult {
  const amount = Math.max(1, Math.min(count, 9999))
  switch (motion) {
    case "h": {
      let next = cursor
      for (let index = 0; index < amount; index++) {
        const candidate = previousGrapheme(text, next)
        if (candidate < lineStart(text, cursor)) break
        next = candidate
      }
      return { cursor: next }
    }
    case "l": {
      let next = cursor
      const end = lineEnd(text, cursor)
      for (let index = 0; index < amount; index++) {
        const candidate = nextGrapheme(text, next)
        if (candidate >= end) break
        next = candidate
      }
      return { cursor: next }
    }
    case "j":
      return vertical(text, cursor, amount, preferredColumn)
    case "k":
      return vertical(text, cursor, -amount, preferredColumn)
    case "w":
      return { cursor: wordNext(text, cursor, amount, false) }
    case "W":
      return { cursor: wordNext(text, cursor, amount, true) }
    case "b":
      return { cursor: wordPrevious(text, cursor, amount, false) }
    case "B":
      return { cursor: wordPrevious(text, cursor, amount, true) }
    case "e":
      return { cursor: wordEnd(text, cursor, amount, false), inclusive: true }
    case "E":
      return { cursor: wordEnd(text, cursor, amount, true), inclusive: true }
    case "0":
      return { cursor: lineStart(text, cursor) }
    case "^":
      return { cursor: firstNonBlank(text, cursor) }
    case "$": {
      const end = lineEnd(text, cursor)
      return { cursor: end > lineStart(text, cursor) ? previousGrapheme(text, end) : end, inclusive: true }
    }
    case "gg": {
      const starts = lineStarts(text)
      const row = count > 1 ? Math.min(starts.length - 1, count - 1) : 0
      return { cursor: starts[row] ?? 0, linewise: true }
    }
    case "G": {
      const starts = lineStarts(text)
      const row = count > 1 ? Math.min(starts.length - 1, count - 1) : starts.length - 1
      return { cursor: starts[row] ?? 0, linewise: true }
    }
    case "%": {
      const match = matchingBracket(text, cursor)
      return match === undefined ? { cursor, failed: true } : { cursor: match, inclusive: true }
    }
    case "{":
      return { cursor: paragraph(text, cursor, -1, amount), linewise: true }
    case "}":
      return { cursor: paragraph(text, cursor, 1, amount), linewise: true }
  }
}

export function resolveFind(text: string, cursor: number, find: Find, count = 1): MotionResult | undefined {
  const start = lineStart(text, cursor)
  const end = lineEnd(text, cursor)
  let index = cursor
  for (let iteration = 0; iteration < Math.max(1, count); iteration++) {
    if (find.direction === 1) index = text.indexOf(find.needle, index + 1)
    else index = text.lastIndexOf(find.needle, index - 1)
    if (index < start || index >= end) return
  }
  if (find.till) index = find.direction === 1 ? previousGrapheme(text, index) : nextGrapheme(text, index)
  return { cursor: Math.max(start, Math.min(end, index)), inclusive: true }
}

export function motionRange(text: string, origin: number, result: MotionResult): Range {
  if (result.linewise) {
    const first = Math.min(lineIndexAt(text, origin), lineIndexAt(text, result.cursor))
    const last = Math.max(lineIndexAt(text, origin), lineIndexAt(text, result.cursor))
    const starts = lineStarts(text)
    const start = starts[first] ?? 0
    const next = starts[last + 1]
    if (next !== undefined) return { start, end: next, linewise: true }
    return { start, end: text.length, linewise: true }
  }
  const start = Math.min(origin, result.cursor)
  let end = Math.max(origin, result.cursor)
  if (result.inclusive) end = nextGrapheme(text, end)
  if (start === end && result.cursor === origin && result.inclusive) end = nextGrapheme(text, end)
  return { start, end }
}

export function wordObject(text: string, cursor: number, around: boolean, big: boolean): Range | undefined {
  if (!text) return
  const { list, index } = entryAt(text, cursor)
  if (index < 0) return
  let left = index
  while (left < list.length && charClass(list[left]!.segment, big) === 0) left++
  if (left >= list.length) {
    left = index
    while (left > 0 && charClass(list[left]!.segment, big) === 0) left--
  }
  const cls = charClass(list[left]!.segment, big)
  let right = left
  while (left > 0 && charClass(list[left - 1]!.segment, big) === cls) left--
  while (right + 1 < list.length && charClass(list[right + 1]!.segment, big) === cls) right++
  if (around) {
    let after = right + 1
    while (after < list.length && charClass(list[after]!.segment, big) === 0 && list[after]!.segment !== "\n") after++
    if (after > right + 1) right = after - 1
    else while (left > 0 && charClass(list[left - 1]!.segment, big) === 0 && list[left - 1]!.segment !== "\n") left--
  }
  return { start: list[left]!.index, end: list[right]!.end }
}

export function quoteObject(text: string, cursor: number, quote: string, around: boolean): Range | undefined {
  const start = lineStart(text, cursor)
  const end = lineEnd(text, cursor)
  const positions: number[] = []
  for (let index = start; index < end; index++) {
    if (text[index] !== quote) continue
    let slashes = 0
    for (let previous = index - 1; previous >= start && text[previous] === "\\"; previous--) slashes++
    if (slashes % 2 === 0) positions.push(index)
  }
  for (let index = 0; index + 1 < positions.length; index += 2) {
    const left = positions[index]!
    const right = positions[index + 1]!
    if (cursor < left || cursor > right) continue
    return around ? { start: left, end: right + quote.length } : { start: left + quote.length, end: right }
  }
}

export function bracketObject(text: string, cursor: number, pair: string, around: boolean): Range | undefined {
  const open = pair[0]!
  const close = pair[1]!
  let depth = 0
  let left = -1
  for (let index = cursor; index >= 0; index--) {
    if (text[index] === close) depth++
    if (text[index] === open) {
      if (depth === 0) {
        left = index
        break
      }
      depth--
    }
  }
  if (left < 0) return
  depth = 0
  let right = -1
  for (let index = left; index < text.length; index++) {
    if (text[index] === open) depth++
    if (text[index] === close) {
      depth--
      if (depth === 0) {
        right = index
        break
      }
    }
  }
  if (right < 0 || right < cursor) return
  return around ? { start: left, end: right + 1 } : { start: left + 1, end: right }
}

export function selectionRange(text: string, anchor: number, cursor: number, linewise: boolean): Range {
  if (linewise) {
    const first = Math.min(lineIndexAt(text, anchor), lineIndexAt(text, cursor))
    const last = Math.max(lineIndexAt(text, anchor), lineIndexAt(text, cursor))
    const starts = lineStarts(text)
    return {
      start: starts[first] ?? 0,
      end: starts[last + 1] ?? text.length,
      linewise: true,
    }
  }
  return {
    start: Math.min(anchor, cursor),
    end: nextGrapheme(text, Math.max(anchor, cursor)),
  }
}

export function normalCursor(text: string, cursor: number) {
  if (!text) return 0
  const start = lineStart(text, cursor)
  const end = lineEnd(text, cursor)
  if (end === start) return start
  return Math.min(clampCursor(text, cursor), previousGrapheme(text, end))
}
