# Diff as context

Concept notes for future work. Nothing here is signed off as a feature yet.

## The idea

`git diff --cached` plus the user's message is the full context of a turn.

1. **Claude's turn** ends with an entry appended to `.skogai/journal.md` (the user's prompt, Claude's reply, the actions taken), and then everything is staged.
2. **The user** reviews with `git diff --cached` and commits, usually as `WIP`.
3. **The user's turn** is their message plus whatever they changed and staged themselves.

The staged diff then holds both sides: the journal hunk carries Claude's previous turn, and the other hunks carry the user's edits. Each commit is one complete round: what was asked, what was answered and why, and what changed.

## Current state

- hook-tap 0.5.0 writes the journal and runs `git add -A` on the plain `Stop` hook, from `scripts/events/Stop.sh`, at the git root. The implementation was not signed off. The features are listed in `FEATURES.md`, with details in `.skogai/features/diff-as-handover.md`.
- Nothing commits automatically. Staging only, until the automation can be trusted.
- The big `log.jsonl` stays globally gitignored, as the raw source.

## Known problems

- **Rewound or retried prompts are journaled twice.** The journal keeps a turn even after a rewind.
- **Your diff only shows your changes if you commit Claude's staged turn first.** Otherwise both turns are mixed in one diff.

## Directions, not decided

- Feed `git diff --cached` into context automatically on `UserPromptSubmit`, instead of typing `!git diff --cached`. Declined for now.
