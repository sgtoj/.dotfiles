# Local OpenCode Vim

Local Vim controls for the OpenCode TUI. The implementation is independent and
has no runtime dependency on a third-party Vim plugin. The public behavior of
[`leohenon/opencode-vim-plugin`](https://github.com/leohenon/opencode-vim-plugin)
was used as a feature reference.

## Modes

- Prompt editing starts in insert mode. `Escape` enters normal mode.
- `Enter` submits from insert or normal mode. Use `Alt+Enter` for a newline.
- The second `Escape` from normal mode retains OpenCode's interrupt behavior.
- `/vim` or `Toggle Vim mode` enables and disables the plugin.

## Prompt

Normal mode supports counts; character, word, line, buffer, find, bracket, and
paragraph motions; `d`, `c`, and `y` operators; common text objects; insert,
replace, and visual modes; paste; undo/redo; join; case toggle; and dot repeat.

`Ctrl+d`/`Ctrl+u`, `Ctrl+f`/`Ctrl+b`, and `Ctrl+e`/`Ctrl+y` scroll the
conversation. When the prompt is empty, `j`/`k`, `gg`/`G`, and `{`/`}` also
navigate it. `v`, `Ctrl+v`, or `Ctrl+w k` opens transcript copy mode.

Searchable dialogs start in insert mode. `Escape` enters dialog normal mode,
where `j`/`k`, `gg`/`G`, word motions, and `dd` work; `i` resumes filtering and
a second `Escape` closes the dialog.

## Copy Mode

Copy mode uses a stable transcript snapshot instead of OpenTUI's private render
tree. It supports motions, character and line visual selections, `y`/`yy`,
smart-case `/` and `?` search with `n`/`N`, `i` to return to the prompt, and `q`
to close. Reasoning and tool output can be included with plugin options.

## Development

```sh
bun install --ignore-scripts
bun test
bun run typecheck
```

The pure engine and transcript model are isolated from `index.tsx`, which is the
OpenCode 1 adapter. This keeps a future OpenCode 2 port constrained to the host
adapter and configuration.
