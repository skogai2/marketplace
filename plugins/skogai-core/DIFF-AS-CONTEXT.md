# Diff as context

Concept notes for future work. This is a concept with the goal of being implemented in the long term.

## The idea

`git diff --cached` plus the user's message is the full context of a turn.

1. **Claude's turn** ends with an entry appended to `.skogai/journal.md` (the user's prompt, Claude's reply, the actions taken), and then everything is staged.
2. **The user** reviews with `git diff --cached` and commits, usually as `WIP`.
3. **The user's turn** is their message plus whatever they changed and staged themselves.

The staged diff then holds both sides: the journal hunk carries Claude's previous turn, and the other hunks carry the user's edits. Each commit is one complete round: what was asked, what was answered and why, and what changed.

## Goal

A message exchange where each side's turn is staged and committed automatically, so the history becomes a git-diff bundle: each commit is one turn's intent (the message, appended to the journal) plus its change.

Each turn, the other party sees:

- the message sent,
- `git diff` and `git diff --cached`: what changed this turn,
- `wt step diff`: everything since branching from the default branch (committed, staged, unstaged and untracked). It fits wt's model: each worktree is a work order against `master`, and new files show up without being added first.

The diffs carry context on their own. A hunk that edits a doc like this one shows the change and the intent behind it together.

## Current state

- `scripts/events/Stop.sh` writes the journal at the git root on every `Stop`.
- Git steps are env switches, all off unless set to `true`, read by `scripts/git-steps.sh` on `Stop` and `UserPromptSubmit`: `SKOGAI_{STAGE,COMMIT,MERGE}_ON_{STOP,USER_PROMPT_SUBMIT}` run `git add -A`, `wt step commit` and `wt merge --no-remove`. The user sets them globally through mise, all `false` to start. Details in `.skogai/features/diff-as-handover.md`.
- `scripts/write-state.sh` writes `git-diff`, `git-diff-cached` and `wt-step-diff` to `.skogai/tmp/` at the git root on `SessionStart`, `UserPromptSubmit` and `Stop`. The directory ignores itself. Nothing injects them into context yet.
- The big `log.jsonl` stays globally gitignored, as the raw source.

## Known problems

- **Rewound or retried prompts are journaled twice.** The journal keeps a turn even after a rewind.
- **Your diff only shows your changes if you commit Claude's staged turn first.** Otherwise both turns are mixed in one diff.

## Directions, not decided

- Feed the diffs into context automatically on `UserPromptSubmit`, instead of typing `!git diff --cached` or `@.skogai/tmp/wt-step-diff`. Declined for now; the goal above is where this leads.
