# Features

- Show the current hook event in the status line (`hook: <stage>`).
- Log each event's input as one JSON line to `.skogai/logs/hook-tap/log.jsonl`.
- Turn journal: on `turn.complete`, append the turn's prompt, the assistant's text, and its tool actions to `.skogai/journal.md` (tracked), then stage everything with `git add -A`. Review with `git diff --cached`; committing stays manual for now.
