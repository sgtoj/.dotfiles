import type { TuiPlugin, TuiPluginModule } from "@opencode-ai/plugin/tui"

const NOTIFY = `${process.env.HOME}/.dotfiles/.local/bin/oc-notify`

type RawEvent = { type: string; properties?: Record<string, any> }

function flatten(value: string, max = 120): string {
  const text = value.replace(/\s+/g, " ").trim()
  return text.length > max ? `${text.slice(0, max - 1)}...` : text
}

function firstText(...candidates: unknown[]): string {
  for (const candidate of candidates) {
    if (typeof candidate === "string" && candidate.trim()) return flatten(candidate)
  }
  return ""
}

const tui: TuiPlugin = async (api) => {
  const pane = process.env.TMUX_PANE
  if (!pane || !process.env.TMUX) return

  const label = api.state.path.directory.split("/").filter(Boolean).pop() ?? "opencode"
  const children = new Set<string>()
  const notify = (args: string[]) => Bun.spawn([NOTIFY, ...args], { stdout: "ignore", stderr: "ignore" })
  const flag = (state: string, detail = "", sound = state) => notify(["set", pane, state, label, detail, sound])
  const clear = () => notify(["clear", pane])

  const stop = (api.event.on as any)("*", (event: unknown) => {
    const { type, properties } = event as RawEvent
    switch (type) {
      case "session.created":
        if (properties?.info?.id && properties.info.parentID) children.add(properties.info.id)
        break
      case "permission.asked":
        flag("waiting", firstText(properties?.title, properties?.tool?.name, properties?.tool, properties?.pattern, "needs permission"), "permission")
        break
      case "question.asked":
        flag("waiting", firstText(properties?.header, properties?.question, properties?.questions?.[0]?.header, properties?.questions?.[0]?.question, "asked a question"), "question")
        break
      case "session.error":
        flag("error", firstText(properties?.error?.data?.message, properties?.error?.message, properties?.error?.name, "session error"))
        break
      case "session.idle":
        if (!children.has(properties?.sessionID)) flag("done")
        break
      case "session.status":
        if (properties?.status?.type === "busy") clear()
        break
      case "permission.replied":
      case "question.replied":
      case "question.rejected":
        clear()
        break
    }
  })

  api.lifecycle.onDispose(stop)
}

export default {
  id: "local.tmux-notify-v1",
  tui,
} satisfies TuiPluginModule & { id: string }
