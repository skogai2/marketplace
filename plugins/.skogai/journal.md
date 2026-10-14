## 2026-10-14 12:11 · turn f95c31d9

**User**

> hi claude! id like to update @plugins/hook-tap/ in general - especially the features.md file so it have a explanation of what the end goal should look like etc

**Assistant**

Next, the general fixes: the README run paths are stale, and the README and DIFF-AS-CONTEXT should point to FEATURES.md.

I rewrote `plugins/hook-tap/FEATURES.md` so it starts with the end goal: git is the only memory between turns and sessions. I worked that goal out from `DIFF-AS-CONTEXT.md` and `.skogai/features/diff-as-handover.md`, so read it and change anything that isn't what you actually want.

**The new FEATURES.md has:**
- **End goal:** each `WIP` commit is one complete round, `git diff --cached` plus the next message is the full context, and a new session starts with the uncommitted state already loaded.
- **What a finished round looks like:** the five steps from your message to the next commit.
- **Feature table:** status column for each feature:
  - The status line, the event log, and steps 1 and 2 of diff-as-handover (journal entry, then `git add -A`) are built. Steps 1 and 2 still use the session's working directory instead of the git root.
  - Step 3 (writing the diffs to `.skogai/tmp/` when a session starts) isn't built.
- **Left to reach the goal:** resolve paths against the git root, build step 3, stop journaling rewound turns twice, and handle the 4 MiB read limit from rewriting whole files.
- **Not goals:** no automatic commits, no diff added to context mid-session, and `log.jsonl` is never committed.

**Other fixes:**
- `README.md`: the run instructions pointed to `~/skogai-fleet`, which doesn't exist. They now use `~/marketplace` and `plugins/hook-tap`. The intro now links to FEATURES.md for the end goal.
- `LEARNINGS.md`: the same stale path is fixed.
- `DIFF-AS-CONTEXT.md`: replaced the sentence about who edited the FEATURES.md row with a pointer to FEATURES.md.

`claude plugin validate` passes, with only the usual warnings. I didn't stage or commit anything, so you can review with `git diff` first.

**Actions**

- Bash: `cd /home/skogix/marketplace/plugins/hook-tap && for f in FEATURES.md README.md CLAUDE.md DIFF-AS-CONTEXT.md LEARNINGS.md…`
- Bash: `cat .skogai/CLAUDE.md .skogai/features/diff-as-handover.md hooks/hooks.json hooks/register.ts; ls -la .skogai; git log -…`
- Bash: `ls -d ~/skogai-fleet 2>&1; cd /home/skogix/marketplace && git log -3 --stat --format='%h %s' -- plugins/hook-tap | head …`
- Write `plugins/hook-tap/FEATURES.md`
- Bash: `cd /home/skogix/marketplace/plugins/hook-tap && python3 - <<'EOF'`

