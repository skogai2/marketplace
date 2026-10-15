#!/usr/bin/env bash
# Runs the git steps switched on for one event, from the git root, and prints
# what ran as a comma-separated list for the log.
# Usage: git-steps.sh <EVENT> <root>   (EVENT: STOP or USER_PROMPT_SUBMIT)
# Switches: SKOGAI_STAGE_ON_<EVENT>=true runs `git add -A`,
#           SKOGAI_MERGE_ON_<EVENT>=true runs `wt merge` after staging.
set -euo pipefail

event=$1 root=$2
stage_var=SKOGAI_STAGE_ON_$event
merge_var=SKOGAI_MERGE_ON_$event
ran=()

if [[ ${!stage_var:-} == true ]]; then
  git -C "$root" add -A
  ran+=("git add -A")
fi

# --no-remove keeps the worktree the session is running in. wt's output goes
# to stderr so it never lands in Claude's context, and a failed merge (say, on
# the default branch) is logged instead of failing the hook.
if [[ ${!merge_var:-} == true ]]; then
  if wt -C "$root" merge --no-remove >&2; then
    ran+=("wt merge")
  else
    ran+=("wt merge (failed)")
  fi
fi

(IFS=,; printf '%s' "${ran[*]}" | sed 's/,/, /g')
