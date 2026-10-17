# Diff as handover

Each turn leaves the working tree in a state where `git diff --cached` plus the next message is the full context. Nothing else needs to be remembered between turns or sessions.

## Context

1. **Record.** At the end of each turn, append the user's prompt, Claude's reply and the actions taken to `.skogai/journal.md` at the git root.
2. **Stage.** Then, if switched on, run `git add -A` from the git root. Nothing commits unless that is switched on too; otherwise the user reviews with `git diff --cached` and commits, usually as `WIP`.
3. **Hand over.** Write the current state as diff files to `.skogai/tmp/` at the git root: `git-diff`, `git-diff-cached` and `wt-step-diff` (`wt step diff`: everything since branching from the default branch, untracked files included). Later, these go into context so a new session or turn starts with the state already known.

## Status

- Steps 1 and 2 are built: `scripts/events/Stop.sh` runs them on `Stop`, at the git root. Step 2 only runs with `SKOGAI_STAGE_ONSTOP=true`. It finds the turn's prompt and tool uses in the event log by `prompt_id`, and the reply in `last_assistant_message`.
- `Stop` doesn't fire on an interrupted turn, so interrupted turns aren't journaled. The entry holds Claude's final message only, not text from earlier in the turn.
- Git steps are switched by dash's `skogai config` keys (`stage.on-stop`, ...), read by `scripts/git-steps.sh` from the git root, so `.skogai/config` and `~/.skogai/config` apply. Each key's env var overrides it, and without a working `skogai` on PATH the env vars are all there is. All are off unless `true`, and run in table order:

  | Env (`<EVENT>` is `STOP` or `USERPROMPTSUBMIT`) | Runs |
  |---|---|
  | `SKOGAI_STAGE_ON<EVENT>` | `git add -A` |
  | `SKOGAI_COMMIT_ON<EVENT>` | `wt step commit`, skipped when the tree is clean |
  | `SKOGAI_MERGE_ON<EVENT>` | `wt merge --no-remove` |

  A failed `wt` step is logged with `(failed)` and doesn't fail the hook.
- Step 3 is half built: `scripts/write-state.sh` overwrites the three files on `SessionStart`, and on `UserPromptSubmit` and `Stop` after the git steps. `.skogai/tmp/` holds a `.gitignore` of `*`, so staging never picks the files up. Without `wt`, `wt-step-diff` is left empty. Nothing feeds the files into context yet.

## Left out on purpose

- No automatic commits unless switched on.
- No mid-session diff injection.
