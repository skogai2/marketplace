# Diff as handover

Each turn leaves the working tree in a state where `git diff --cached` plus the next message is the full context. Nothing else needs to be remembered between turns or sessions.

## Context

1. **Record.** At the end of each turn, append the user's prompt, Claude's reply and the actions taken to `.skogai/journal.md` at the git root.
2. **Stage.** Then run `git add -A` from the git root. Nothing commits automatically; the user reviews with `git diff --cached` and commits, usually as `WIP`.
3. **Hand over.** At session start, write `git diff` and `git diff --cached` to `.skogai/tmp/`, which `CLAUDE.md` imports. A new session then starts with the uncommitted state already in context.

