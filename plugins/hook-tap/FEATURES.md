# Features

- Show the current hook event in the status line (`hook: <stage>`).
- Log each event's input as one JSON line to `.skogai/logs/hook-tap/log.jsonl`.
- @.skogai/features/diff-as-handover.md - each turn ends with a journal entry (prompt, reply, actions) in `.skogai/journal.md` and everything staged, so `git diff --cached` plus the next message is the full context; each `WIP` commit is one round.
