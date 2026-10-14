# Features

## End goal

Git is the only memory between turns and sessions. When hook-tap is done:

- Every turn ends with the working tree staged and a journal entry saying what was asked, what was answered, and what was done.
- `git diff --cached` plus the next message is the full context of a turn. Nothing else has to be remembered, re-explained or pasted in.
- Every `WIP` commit is one complete round: the user's message and edits, Claude's reply and edits, and the reason for each change, side by side in one diff.
- A new session starts with the uncommitted state already in context, so picking up work after `/clear`, a crash or a new day costs nothing.
- The event log stays as the raw source underneath, for debugging and for learning how hooks fire.

### What a finished round looks like

1. The user writes a message, maybe after editing and staging files themselves.
2. Claude works. The status line shows which hook stage it's in.
3. The turn ends. hook-tap appends the entry to `.skogai/journal.md` at the git root and runs `git add -A` from the git root.
4. The user reads `git diff --cached`, commits as `WIP` (or fixes things first), and writes the next message.
5. If the session ends, the next one opens with `git diff` and `git diff --cached` already loaded.

## Features

| Feature | Status | Details |
|---|---|---|
| Status line shows the current hook event (`hook: <stage>`) | Built | `hooks/register.ts` |
| Each event's input logged as one JSON line to `.skogai/logs/hook-tap/log.jsonl` | Built | [README.md](README.md#what-is-logged) |
| Diff as handover, step 1: journal entry (prompt, reply, actions) on `turn.complete` | Built, not at git root yet | [diff-as-handover.md](.skogai/features/diff-as-handover.md) |
| Diff as handover, step 2: `git add -A` after the journal entry | Built, not at git root yet | [diff-as-handover.md](.skogai/features/diff-as-handover.md) |
| Diff as handover, step 3: write the diffs to `.skogai/tmp/` on session start | Not built | [diff-as-handover.md](.skogai/features/diff-as-handover.md) |

## Left to reach the goal

- **Resolve paths against the git root.** The journal and `git add -A` follow the session's working directory today.
- **Build step 3.** Write `git diff` and `git diff --cached` to `.skogai/tmp/` at session start, and import them from the root `CLAUDE.md`.
- **Don't journal rewound or retried turns twice.**
- **Stop rewriting whole files.** `$.fs` has no append, so the journal and the log are read and rewritten on every write and will hit the 4 MiB read limit. Rotate them, or move the writes to a script.

## Not goals

- No automatic commits. The user commits, until staging can be trusted.
- No diff injected into context mid-session. Session start only.
- `log.jsonl` is never committed.
