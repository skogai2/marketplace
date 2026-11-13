# Diff as handover

Each turn leaves the working tree in a state where `git diff --cached` plus the next message is the full context. Nothing else needs to be remembered between turns or sessions.

## Context

1. **Record.** At the end of each turn, append the user's prompt, Claude's reply and the actions taken to `.skogai/journal.md` at the git root.
2. **Stage.** Then, if switched on, run `git add -A` from the git root. Nothing commits unless that is switched on too; otherwise the user reviews with `git diff --cached` and commits, usually as `WIP`.
3. **Hand over.** Write the current state as diff files to `.skogai/tmp/` at the git root: `git-diff`, `git-diff-cached` and `wt-step-diff` (`wt step diff`: everything since branching from the default branch, untracked files included). Later, these go into context so a new session or turn starts with the state already known.

## Status

- Steps 1 and 2 are built: `scripts/events/Stop.sh` runs them on `Stop`, at the git root. Step 1 runs with the `journal` mod setting on, step 2 with `stage_on_stop`. It finds the turn's prompt and tool uses in the event log by `prompt_id`, and the reply in `last_assistant_message`.
- `Stop` doesn't fire on an interrupted turn, so interrupted turns aren't journaled. The entry holds Claude's final message only, not text from earlier in the turn.
- Git steps are mod settings (see the README's settings table), all off by default, and run in table order (`<event>` is `stop` or `prompt`):

  | Setting | Runs |
  |---|---|
  | `journal` | `git add` and `git commit --only` of the journal (only on `Stop`; the log is never committed), skipped when it's unchanged |
  | `stage_on_<event>` | `git add -A` |
  | `commit_on_<event>` | `wt step commit`, skipped when the tree is clean |
  | `merge_on_<event>` | `wt merge --no-remove` |

  A failed `wt` step is logged with `(failed)` and doesn't fail the hook.
- Step 3 is half built: with `write_state` on, `scripts/write-state.sh` overwrites the three files on `SessionStart`, and on `UserPromptSubmit` and `Stop` after the git steps. `.skogai/tmp/` holds a `.gitignore` of `*`, so staging never picks the files up. Without `wt`, `wt-step-diff` is left empty. Nothing feeds the files into context yet.

## Left out on purpose

- No automatic commits of anything but the journal unless switched on. The log stays untracked (gitignored).
- No mid-session diff injection.
