# Diff as handover

Each turn leaves the working tree in a state where `git diff --cached` plus the next message is the full context. Nothing else needs to be remembered between turns or sessions.

## Context

1. **Record.** At the end of each turn, append the user's prompt, Claude's reply and the actions taken to `.skogai/journal.md` at the git root.
2. **Stage.** Then run `git add -A` from the git root. Nothing commits automatically; the user reviews with `git diff --cached` and commits, usually as `WIP`.
3. **Hand over.** At session start, write `git diff` and `git diff --cached` to `.skogai/tmp/` at the git root, which the root `CLAUDE.md` imports. A new session then starts with the uncommitted state already in context.

## Status

- Steps 1 and 2 are built: `scripts/events/Stop.sh` runs them on `Stop`, at the git root. It finds the turn's prompt and tool uses in the event log by `prompt_id`, and the reply in `last_assistant_message`.
- `Stop` doesn't fire on an interrupted turn, so interrupted turns aren't journaled. The entry holds Claude's final message only, not text from earlier in the turn.
- Step 3 is not built yet. Nothing writes `.skogai/tmp/git-diff` or `.skogai/tmp/git-diff-cached`.

## Left out on purpose

- No automatic commits until the staging can be trusted.
- No mid-session diff injection.
