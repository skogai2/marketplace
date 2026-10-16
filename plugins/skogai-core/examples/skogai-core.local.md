---
# Copy to .claude/skogai-core.local.md at the git root of the project where
# you run Claude. Everything here is optional: with no file, skogai-core logs
# every event and acts as usual. Check it with scripts/validate-settings.sh.

# false switches the plugin off: no log rows, no journal, no git steps, no
# status line.
enabled: true

# Only log these hook events (globs allowed, such as "Post*"). Omit or leave
# empty to log all of them. The journal needs UserPromptSubmit, PostToolUse
# and PostToolUseFailure rows, so leaving those out empties its entries.
events: ["SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure", "Stop"]

# Where to append events, relative to the git root.
log_path: ".skogai/logs/skogai-core/log.jsonl"

# Show "hook: <event>" in the status line.
status_line: true
---

# skogai-core: this project

Notes for yourself go here; skogai-core reads only the frontmatter.
