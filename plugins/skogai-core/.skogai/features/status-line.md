# Status line

Shows the event we are acting upon, as `hook: <event>`.

## Why

skogai-core exists to act upon events. The status line shows which one we're acting on right now.

## How

The status line is the only part that is a mod, because only a mod can call `$.ui.status`. `hooks/register.ts` hooks `session.start`, `turn.start`, `tool.call` and `turn.complete` (not `classic.*`: the built-in `cc-plugin-sec-default` guard passes settings hook events past user-installed mods, so a `classic.*` hook is skipped every time). Each lets the event run first, then reads the last row of the log with `tail -n1` and shows its `event`. The log is the single source of truth; the status line is a view of its last row.

## Status

- Built in 0.5.0.
- Checked in an interactive session after `/reload-plugins`.

## Left out on purpose

- Off unless the `enabled` and `status_line` mod settings are both on; otherwise the module registers no hooks at all.
- Only the event name. Nothing else is shown.
- No `$.fs.read` of the log, which would fail once it passes 4 MiB.
