# Features

- Show the current hook event in the status line (`hook: <stage>`). Details: [.skogai/features/status-line.md](.skogai/features/status-line.md)
- Log each event we act upon, and what we did, as one JSON line to `.skogai/logs/hook-tap/log.jsonl` at the git root. Details: [.skogai/features/event-log.md](.skogai/features/event-log.md)
- Diff as handover: on `Stop`, each turn ends with a journal entry (prompt, reply, actions) in `.skogai/journal.md` and everything staged with `git add -A`, so `git diff --cached` plus the next message is the full context; each `WIP` commit is one round. Details: [.skogai/features/diff-as-handover.md](.skogai/features/diff-as-handover.md)
