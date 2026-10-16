---
# Copy to .claude/hook-tap.local.md in the project where you run Claude.
# Everything here is optional: with no file, hook-tap logs every stage.

enabled: true

# Only log these stages. Omit or leave empty to log all of them.
stages: ["session.start", "session.end", "tool.call", "classic.*"]

# Where to append events, relative to the session's working directory.
log_path: ".skogai/logs/hook-tap/log.jsonl"

# Show "hook: <stage>" in the status line.
status_line: true
---

# hook-tap: this project

Narrowed to session lifecycle and tool calls while debugging why the
PreToolUse hook from skoghooks isn't firing. Switch `stages` back to all
of them once that's sorted.
