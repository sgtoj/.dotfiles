import { describe, expect, test } from "bun:test"
import {
  buildTranscript,
  copySelection,
  handleCopyKey,
  initialCopyState,
  setCopySearch,
} from "./transcript"

const input = [
  {
    info: { id: "m1", role: "user", time: { created: 1 } },
    parts: [{ id: "p1", type: "text", text: "hello world" }],
  },
  {
    info: { id: "m2", role: "assistant", time: { created: 2 } },
    parts: [
      { id: "p2", type: "text", text: "first line\nsecond line" },
      { id: "p3", type: "tool", tool: "read", state: { status: "completed", output: "file text" } },
    ],
  },
]

describe("transcript normalization", () => {
  test("builds stable role and content lines", () => {
    const document = buildTranscript(input)
    expect(document.lines.map((line) => line.text)).toEqual([
      "You",
      "hello world",
      "",
      "Assistant",
      "first line",
      "second line",
      "[tool: read (completed)]",
    ])
  })

  test("optionally includes tool output", () => {
    const document = buildTranscript(input, { toolOutput: true })
    expect(document.text).toContain("file text")
  })
})

describe("copy mode", () => {
  test("moves and creates a character selection", () => {
    const document = buildTranscript(input)
    let state = initialCopyState(document)
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "j").state
    state = handleCopyKey(state, document, "v").state
    state = handleCopyKey(state, document, "e").state
    const range = copySelection(state, document)
    expect(document.text.slice(range!.start, range!.end)).toBe("hello")
  })

  test("yanks complete lines", () => {
    const document = buildTranscript(input)
    let state = initialCopyState(document)
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "j").state
    const first = handleCopyKey(state, document, "y")
    const second = handleCopyKey(first.state, document, "y")
    expect(second.effects).toEqual([{ type: "yank", text: "hello world\n", linewise: true }])
  })

  test("searches with smart case and cycles matches", () => {
    const document = buildTranscript(input)
    let state = setCopySearch(initialCopyState(document), document, "line", 1)
    expect(state.matches).toHaveLength(2)
    const next = handleCopyKey(state, document, "n")
    expect(next.state.cursor).not.toBe(state.cursor)
    state = setCopySearch(initialCopyState(document), document, "Line", 1)
    expect(state.matches).toHaveLength(0)
  })

  test("keeps Unicode search offsets aligned to the original transcript", () => {
    const document = buildTranscript([
      {
        info: { id: "unicode", role: "assistant", time: { created: 1 } },
        parts: [{ id: "unicode-part", type: "text", text: "İx ix 😀x" }],
      },
    ])
    const state = setCopySearch(initialCopyState(document), document, "x", 1)
    expect(state.matches.map((range) => document.text.slice(range.start, range.end))).toEqual(["x", "x", "x"])
  })

  test("starts the copy cursor at the beginning of the final grapheme", () => {
    const document = buildTranscript([
      {
        info: { id: "emoji", role: "assistant", time: { created: 1 } },
        parts: [{ id: "emoji-part", type: "text", text: "done 😀" }],
      },
    ])
    const state = initialCopyState(document)
    expect(document.text.slice(state.cursor)).toBe("😀")
  })

  test("preserves counts for pending copy commands", () => {
    const document = buildTranscript(input)
    let state = initialCopyState(document)
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "g").state
    state = handleCopyKey(state, document, "2").state
    state = handleCopyKey(state, document, "y").state
    const result = handleCopyKey(state, document, "y")
    expect(result.effects[0]).toEqual({ type: "yank", text: "You\nhello world\n", linewise: true })
  })
})
