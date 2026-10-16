# Features

- Show the current hook event in the status line (`hook: <stage>`). Details: [.skogai/features/status-line.md](.skogai/features/status-line.md)
- Log each event we act upon, and what we did, as one JSON line to `.skogai/logs/skogai-core/log.jsonl` at the git root. Details: [.skogai/features/event-log.md](.skogai/features/event-log.md)
- Diff as handover: on `Stop`, each turn ends with a journal entry (prompt, reply, actions) in `.skogai/journal.md`, and env switches can stage (`git add -A`), commit (`wt step commit`) and merge (`wt merge`) on turn start or end, so `git diff --cached` plus the next message is the full context; each `WIP` commit is one round. Details: [DIFF-AS-CONTEXT.md](DIFF-AS-CONTEXT.md)
- Per-project settings in `.claude/skogai-core.local.md`: switch the plugin off, pick which events to log, move the log, hide the status line. Details: [README.md#settings](README.md#settings)
- Proposed: read config through dash's `skogai config` (git-config base → global → local → env), adding frontmatter `<file>.md` → `<file>.local.md` layers in the same key space, with state kept apart. Design: [CONFIG.md](CONFIG.md)
