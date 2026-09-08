import { Plugin } from "@opencode/plugin/tui"

const NOTIFY = `${process.env.HOME}/.dotfiles/.local/bin/oc-notify`

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

export default Plugin.define({
  id: "local.tmux-notify",
  setup(context) {
    const pane = process.env.TMUX_PANE
    if (!pane || !process.env.TMUX) return

    const label = (context.location?.directory ?? process.cwd()).split("/").filter(Boolean).pop() ?? "opencode"
    const notify = (args: string[]) => Bun.spawn([NOTIFY, ...args], { stdout: "ignore", stderr: "ignore" })
    const flag = (state: string, detail = "", sound = state) =>
      notify(["set", pane, state, label, detail, sound])
    const clear = () => notify(["clear", pane])

    // OpenCode 2 uses one background service for every terminal. Scope the shared event
    // stream to the session family displayed by this TUI so one pane cannot flag another.
    const currentSession = () => {
      const route = context.ui.router.current()
      return route.type === "session" ? route.sessionID : undefined
    }
    const root = (sessionID: string) => context.data.session.root(sessionID) || sessionID
    const currentFamily = (sessionID: string) => {
      const current = currentSession()
      return !!current && root(current) === root(sessionID)
    }
    const currentRoot = (sessionID: string) => currentFamily(sessionID) && root(sessionID) === sessionID

    // Remove a stale marker left by a previous TUI process in this pane.
    clear()

    const stop = [
      context.data.on("permission.asked", (event) => {
        if (!currentFamily(event.data.sessionID)) return
        flag("waiting", firstText(event.data.message, event.data.action, event.data.resources[0], "needs permission"), "permission")
      }),
      context.data.on("form.created", (event) => {
        if (!currentFamily(event.data.form.sessionID)) return
        flag("waiting", firstText(event.data.form.title, "asked a question"), "question")
      }),
      context.data.on("session.execution.started", (event) => {
        if (currentFamily(event.data.sessionID)) clear()
      }),
      // Older V2 beta builds publish status/idle compatibility events instead of the
      // durable execution pair. Listening to both is safe because oc-notify deduplicates.
      context.data.on("session.status", (event) => {
        if (currentFamily(event.data.sessionID) && event.data.status.type === "busy") clear()
      }),
      context.data.on("session.execution.succeeded", (event) => {
        if (currentRoot(event.data.sessionID)) flag("done")
      }),
      context.data.on("session.idle", (event) => {
        if (currentRoot(event.data.sessionID)) flag("done")
      }),
      context.data.on("session.execution.failed", (event) => {
        if (currentRoot(event.data.sessionID)) {
          flag("error", firstText(event.data.error.message, "session error"))
        }
      }),
      context.data.on("session.execution.interrupted", (event) => {
        if (currentRoot(event.data.sessionID)) clear()
      }),
      context.data.on("permission.replied", (event) => {
        if (currentFamily(event.data.sessionID)) clear()
      }),
      context.data.on("form.replied", (event) => {
        if (currentFamily(event.data.sessionID)) clear()
      }),
      context.data.on("form.cancelled", (event) => {
        if (currentFamily(event.data.sessionID)) clear()
      }),
    ]

    return () => {
      stop.forEach((unsubscribe) => unsubscribe())
      clear()
    }
  },
})
