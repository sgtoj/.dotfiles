import type { Plugin } from "@opencode-ai/plugin"

/**
 * Surface opencode panes that need attention, across every tmux session.
 *
 * This file is only an event source. Every tmux/macOS decision lives in
 * ~/.dotfiles/.local/bin/oc-notify so the behaviour can be tested from a shell.
 *
 * The pane is identified by $TMUX_PANE, which the opencode server process inherits
 * from the shell tmux spawned for the pane. tmux pane ids are permanent, so this
 * stays correct even if the pane is later moved to another window or session.
 */

const NOTIFY = `${process.env.HOME}/.dotfiles/.local/bin/oc-notify`

/**
 * Runtime events are v2-shaped ("permission.asked", "question.asked"), but the Event
 * type re-exported by @opencode-ai/plugin still resolves to the v1 union, which has no
 * such members. Narrow structurally instead of fighting that mismatch.
 */
type RawEvent = { type: string; properties?: Record<string, any> }

function flatten(value: string, max = 120): string {
  const text = value.replace(/\s+/g, " ").trim()
  return text.length > max ? `${text.slice(0, max - 1)}…` : text
}

/** First non-blank string among the candidates, so payload shape drift degrades quietly. */
function firstText(...candidates: unknown[]): string {
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim()) return flatten(candidate)
  }
  return ""
}

function describe(type: string, properties?: Record<string, any>): string {
  switch (type) {
    case "permission.asked":
      return firstText(
        properties?.title,
        properties?.tool?.name,
        properties?.tool,
        properties?.pattern,
        properties?.type,
        "needs permission",
      )
    case "question.asked":
      return firstText(
        properties?.header,
        properties?.question,
        properties?.questions?.[0]?.header,
        properties?.questions?.[0]?.question,
        "asked a question",
      )
    case "session.error":
      return firstText(
        properties?.error?.data?.message,
        properties?.error?.message,
        properties?.error?.name,
        "session error",
      )
    default:
      return ""
  }
}

export const TmuxNotify: Plugin = async ({ directory, $ }) => {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return {}

  const label = directory.split("/").filter(Boolean).pop() ?? "opencode"

  /**
   * session.idle also fires for subagent sessions, so without this filter every Task
   * tool completion would notify.
   *
   * session.created carries the full Session (including parentID) and is always seen
   * before that session can go idle, so parentage is tracked locally. Querying the
   * server instead would add an HTTP round trip that `opencode run` can outlive,
   * losing the notification entirely.
   */
  const children = new Set<string>()

  /**
   * Bun's $ escapes interpolated values, so titles cannot inject shell.
   *
   * Deliberately stateless: oc-notify dedupes against the real tmux option. Caching the
   * last state here would drift, because the pane-focus-in hook clears flags out of band,
   * and a stale cache would swallow a later alert.
   */
  const notify = (args: string[]) => $`${NOTIFY} ${args}`.quiet().nothrow()
  const flag = (state: string, detail: string) => notify(["set", pane, state, label, detail])
  const clear = () => notify(["clear", pane])

  return {
    event: async ({ event }) => {
      const { type, properties } = event as unknown as RawEvent

      switch (type) {
        case "session.created": {
          const info = properties?.info
          if (info?.id && info?.parentID) children.add(info.id)
          break
        }

        // Blocked on a human: loud.
        case "permission.asked":
        case "question.asked":
          await flag("waiting", describe(type, properties))
          break

        case "session.error":
          await flag("error", describe(type, properties))
          break

        // Turn finished: quiet (sound + status bar, no banner).
        case "session.idle":
          if (!children.has(properties?.sessionID)) await flag("done", "")
          break

        // Work resumed, or the prompt was answered.
        case "session.status":
          if (properties?.status?.type === "busy") await clear()
          break
        case "permission.replied":
        case "question.replied":
        case "question.rejected":
          await clear()
          break
      }
    },
  }
}
