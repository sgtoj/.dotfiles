import { describe, expect, test } from "bun:test"
import { currentSelection, handleKey, initialState, trackInsert, type Frame, type VimState } from "./engine"

function run(text: string, cursor: number, keys: string[], state: VimState = initialState("normal")) {
  let frame: Frame = { text, cursor }
  for (const key of keys) {
    const step = handleKey(state, frame, key)
    state = step.state
    frame = step.frame
  }
  return { state, frame }
}

describe("motions", () => {
  test("moves by words and line boundaries", () => {
    expect(run("one two", 0, ["w"]).frame.cursor).toBe(4)
    expect(run("one two", 5, ["b"]).frame.cursor).toBe(4)
    expect(run("one two", 0, ["e"]).frame.cursor).toBe(2)
    expect(run("  one", 4, ["^"]).frame.cursor).toBe(2)
    expect(run("one\ntwo", 1, ["j"]).frame.cursor).toBe(5)
  })

  test("supports counts and buffer motions", () => {
    expect(run("a b c d", 0, ["3", "w"]).frame.cursor).toBe(6)
    expect(run("one\ntwo\nthree", 8, ["g", "g"]).frame.cursor).toBe(0)
    expect(run("one\ntwo\nthree", 0, ["G"]).frame.cursor).toBe(8)
    expect(run("one\ntwo\nthree", 0, ["2", "G"]).frame.cursor).toBe(4)
  })

  test("finds characters and repeats finds", () => {
    const first = run("abc abc", 0, ["f", "c"])
    expect(first.frame.cursor).toBe(2)
    const second = run(first.frame.text, first.frame.cursor, [";"], first.state)
    expect(second.frame.cursor).toBe(6)
    const reverse = run(second.frame.text, second.frame.cursor, [","], second.state)
    expect(reverse.frame.cursor).toBe(2)
  })
})

describe("operators", () => {
  test("deletes and changes with motions", () => {
    expect(run("one two three", 0, ["d", "w"]).frame.text).toBe("two three")
    expect(run("one two three", 4, ["d", "e"]).frame.text).toBe("one  three")

    const changed = run("one two", 0, ["c", "w"])
    expect(changed.state.mode).toBe("insert")
    expect(changed.frame.text).toBe(" two")
  })

  test("supports doubled operators and counts", () => {
    expect(run("one\ntwo\nthree", 0, ["d", "d"]).frame.text).toBe("two\nthree")
    expect(run("one\ntwo\nthree", 0, ["2", "d", "d"]).frame.text).toBe("three")
    expect(run("a b c d", 0, ["2", "d", "2", "w"]).frame.text).toBe("")
  })

  test("supports word and delimiter text objects", () => {
    expect(run("one two three", 5, ["d", "i", "w"]).frame.text).toBe("one  three")
    expect(run("one two three", 5, ["d", "a", "w"]).frame.text).toBe("one three")
    expect(run("one two three", 0, ["2", "d", "i", "w"]).frame.text).toBe(" three")
    expect(run('say "hello" now', 7, ["d", "i", '"']).frame.text).toBe('say "" now')
    expect(run('say "hello" now', 4, ["d", "i", '"']).frame.text).toBe('say "" now')
    expect(run('say "hello" now', 10, ["d", "i", '"']).frame.text).toBe('say "" now')
    expect(run("call(one, two)", 7, ["d", "i", "("]).frame.text).toBe("call()")
  })

  test("operates through find motions", () => {
    expect(run("abc xyz", 0, ["d", "f", "x"]).frame.text).toBe("yz")
    expect(run("abc xyz", 0, ["d", "t", "x"]).frame.text).toBe("xyz")
  })

  test("failed operator motions do not change text", () => {
    expect(run("abc", 0, ["d", "%"]).frame.text).toBe("abc")
    expect(run("abc", 0, ["d", "f", "z"]).frame.text).toBe("abc")
    expect(run("abc", 0, ["d", "h"]).frame.text).toBe("abc")
  })

  test("yanks and puts characterwise text", () => {
    const yanked = run("one two", 0, ["y", "w"])
    expect(yanked.state.register).toEqual({ text: "one ", linewise: false })
    const put = run(yanked.frame.text, 4, ["p"], yanked.state)
    expect(put.frame.text).toBe("one tone wo")
  })

  test("yanks and puts complete lines", () => {
    const yanked = run("one\ntwo", 0, ["y", "y"])
    expect(yanked.state.register).toEqual({ text: "one", linewise: true })
    const moved = run(yanked.frame.text, yanked.frame.cursor, ["j"], yanked.state)
    const put = run(moved.frame.text, moved.frame.cursor, ["p"], moved.state)
    expect(put.frame.text).toBe("one\ntwo\none")
  })

  test("handles final-line ranges without moving into the prior line", () => {
    const yanked = run("one\ntwo", 4, ["y", "y"])
    expect(yanked.state.register).toEqual({ text: "two", linewise: true })
    expect(yanked.frame.cursor).toBe(4)
    expect(run("one\ntwo", 4, ["d", "d"]).frame.text).toBe("one")

    const changed = run("one\ntwo\nthree", 4, ["c", "G"])
    expect(changed.state.mode).toBe("insert")
    expect(changed.frame.text).toBe("one\n")
  })

  test("supports common atomic edits", () => {
    expect(run("abc", 1, ["X"]).frame.text).toBe("bc")
    expect(run("one\ntwo", 0, ["J"]).frame.text).toBe("one two")
    expect(run("AbC", 0, ["3", "~"]).frame.text).toBe("aBc")
    expect(run("a\n\nb", 0, ["J"]).frame.text).toBe("a \nb")
  })

  test("character edits stop at logical line boundaries", () => {
    expect(run("ab\ncd", 0, ["3", "x"]).frame.text).toBe("\ncd")
    expect(run("ab\ncd", 0, ["3", "s"]).frame.text).toBe("\ncd")
    expect(run("a\nb", 0, ["2", "r", "x"]).frame.text).toBe("a\nb")
  })

  test("keeps Unicode edits on grapheme boundaries", () => {
    expect(run("a😀x", 0, ["t", "x", "x"]).frame.text).toBe("ax")
    const yanked = run("😀x", 0, ["y", "l"])
    const moved = run(yanked.frame.text, yanked.frame.cursor, ["l"], yanked.state)
    expect(run(moved.frame.text, moved.frame.cursor, ["p"], moved.state).frame.text).toBe("😀x😀")
  })
})

describe("editing state", () => {
  test("groups insert mode as one undo step", () => {
    let state = initialState("normal")
    let frame: Frame = { text: "one", cursor: 0 }
    let step = handleKey(state, frame, "A")
    state = step.state
    frame = { text: "one two", cursor: 7 }
    step = handleKey(state, frame, "escape")
    expect(step.state.mode).toBe("normal")
    expect(step.frame.cursor).toBe(6)

    const undone = handleKey(step.state, step.frame, "u")
    expect(undone.frame).toEqual({ text: "one", cursor: 0 })
    const redone = handleKey(undone.state, undone.frame, "ctrl+r")
    expect(redone.frame.text).toBe("one two")
  })

  test("tracks the initial insert session", () => {
    const before: Frame = { text: "", cursor: 0 }
    const state = trackInsert(initialState("insert"), before)
    const escaped = handleKey(state, { text: "hello", cursor: 5 }, "escape")
    const undone = handleKey(escaped.state, escaped.frame, "u")
    expect(undone.frame).toEqual(before)
  })

  test("leaves insert mode on the inserted character", () => {
    let state = initialState("normal")
    let frame: Frame = { text: "abc", cursor: 1 }
    let step = handleKey(state, frame, "i")
    state = step.state
    frame = { text: "aXbc", cursor: 2 }
    step = handleKey(state, frame, "escape")
    expect(step.frame.cursor).toBe(1)
    expect(run(step.frame.text, step.frame.cursor, ["x"], step.state).frame.text).toBe("abc")
  })

  test("does not record a no-op insert as an edit", () => {
    let state = initialState("normal")
    const frame: Frame = { text: "abc", cursor: 1 }
    let step = handleKey(state, frame, "a")
    step = handleKey(step.state, step.frame, "escape")
    expect(step.state.undo).toEqual([])
    expect(step.state.lastChange).toBeUndefined()
  })

  test("repeats atomic and insert changes", () => {
    const deleted = run("one two three", 0, ["d", "w"])
    const repeated = run(deleted.frame.text, deleted.frame.cursor, ["."], deleted.state)
    expect(repeated.frame.text).toBe("three")

    let state = initialState("normal")
    let frame: Frame = { text: "a b", cursor: 0 }
    let step = handleKey(state, frame, "a")
    state = step.state
    frame = { text: "a! b", cursor: 2 }
    step = handleKey(state, frame, "escape")
    const moved = run(step.frame.text, step.frame.cursor, ["w"], step.state)
    const dotted = run(moved.frame.text, moved.frame.cursor, ["."], moved.state)
    expect(dotted.frame.text).toBe("a! b!")
  })

  test("tracks visual selections", () => {
    const selected = run("one two", 0, ["v", "e"])
    expect(currentSelection(selected.state, selected.frame)).toEqual({ start: 0, end: 3 })
    const yanked = run(selected.frame.text, selected.frame.cursor, ["y"], selected.state)
    expect(yanked.state.register).toEqual({ text: "one", linewise: false })
    expect(yanked.state.mode).toBe("normal")
  })
})
