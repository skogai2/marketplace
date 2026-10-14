# Event log

One row in `.skogai/logs/hook-tap/log.jsonl` at the git root for each event we act upon, and what we did:

```json
{"ts":"2026-10-14T12:56:01.123Z","event":"Stop","action":"journal entry, git add -A","input":{...the hook's stdin JSON...}}
```

`action` is left out when we only logged the event.

## Why

hook-tap exists to act upon events. The log is the record of every time it did, and the source the other features read from: the status line shows its last row, and the journal finds a turn's prompt and tool uses in it.

## How

- `hooks/hooks.json` is the list of events we act upon. Each one runs `scripts/events/<Event>.sh` with the event's JSON on stdin.
- Each script does what that event needs, then calls `scripts/append-json.sh [action]`, which appends one row with `>>` under `flock`.
- To act upon another event, add it to `hooks.json` and add its script.

## Status

- Built in 0.5.0: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `Notification`, `SubagentStart`, `SubagentStop`, `PreCompact`, `PostCompact`, `Stop`, `StopFailure`, `SessionEnd`. All but `Stop` only log.

## Left out on purpose

- Never committed; `log.jsonl` is gitignored.
- Mod-only events (`prompt.compose`, `ui.*`, `turn.complete`, ...). We act upon plain hook events only.
