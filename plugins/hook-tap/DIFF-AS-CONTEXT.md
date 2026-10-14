# Diff as context

Concept notes for future work. Nothing here is signed off as a feature yet.

## The idea

`git diff --cached` plus the user's message is the full context of a turn.

1. **Claude's turn** ends with an entry appended to `.skogai/journal.md` (the user's prompt, Claude's reply, the actions taken), and then everything is staged.
2. **The user** reviews with `git diff --cached` and commits, usually as `WIP`.
3. **The user's turn** is their message plus whatever they changed and staged themselves.

The staged diff then holds both sides: the journal hunk carries Claude's previous turn, and the other hunks carry the user's edits. Each commit is one complete round: what was asked, what was answered and why, and what changed.

## Current state

- hook-tap 0.4.0 writes the journal and runs `git add -A` on `turn.complete`. It's about 60 lines of TypeScript in `hooks/register.ts`. The implementation was not signed off. The end goal and feature status are in `FEATURES.md`, with details in `.skogai/features/diff-as-handover.md`.
- Nothing commits automatically. Staging only, until the automation can be trusted.
- The big `log.jsonl` stays globally gitignored, as the raw source.

## Known problems

- **Paths follow the session's working directory.** If Claude's shell is in a subdirectory when a turn ends, the journal lands in `<subdir>/.skogai/journal.md` and `git add -A` runs from there. Resolve both against the git root.
- **Rewound or retried prompts are journaled twice.** The journal keeps a turn even after a rewind.
- **The whole journal is rewritten each turn** (`$.fs` has no append), so it will eventually hit the 4 MiB read limit.
- **Your diff only shows your changes if you commit Claude's staged turn first.** Otherwise both turns are mixed in one diff.

## Directions, not decided

- Replace the TypeScript with a short script run by settings hooks: `UserPromptSubmit` writes the prompt, and `Stop` writes `last_assistant_message` and runs `git add -A` from `git rev-parse --show-toplevel`.
- Feed `git diff --cached` into context automatically on `UserPromptSubmit`, instead of typing `!git diff --cached`. Declined for now.
