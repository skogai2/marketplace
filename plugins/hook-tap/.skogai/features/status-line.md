# Status line

Shows the event we are acting upon, as `hook: <event>`.

## Why

hook-tap exists to act upon events. The status line shows which one we're acting on right now.

## How

The status line is the only part that is a mod, because only a mod can call `$.ui.status`. `hooks/register.ts` hooks `classic.*`, which fires for every plain hook event. It lets the plain hooks run first, then reads the last row of the log with `tail -n1` and shows its `event`. The log is the single source of truth; the status line is a view of its last row.

## Status

- Built in 0.5.0.
- Checked in an interactive session after `/reload-plugins`.

## Left out on purpose

- Only the event name. Nothing else is shown.
- No `$.fs.read` of the log, which would fail once it passes 4 MiB.
