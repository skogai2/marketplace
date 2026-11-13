#!/usr/bin/env bash
# Runs the git steps switched on for one event, from the git root, and prints
# what ran as a comma-separated list for the log.
# Usage: git-steps.sh <stop|prompt> <root> [path...]
# In this order, each a mod setting (see settings.sh), off unless true:
#   [path...]          given (Stop passes the journal when `journal` is on):
#                      commit only those paths, leaving the rest of the index alone
#   stage_on_<event>   `git add -A`
#   commit_on_<event>  `wt step commit` (skipped when the tree is clean)
#   merge_on_<event>   `wt merge --no-remove`
set -euo pipefail

event=$1 root=$2
shift 2
. "$(dirname "$0")/settings.sh"
ran=()

# Only paths inside this repo that exist; a journal elsewhere is skipped.
paths=()
for path in "$@"; do
  [[ $path == "$root"/* && -e $path ]] && paths+=("${path#"$root"/}")
done
if [[ ${#paths[@]} -gt 0 ]]; then
  git -C "$root" add -- "${paths[@]}"
  if git -C "$root" diff --cached --quiet -- "${paths[@]}"; then
    : # nothing new since the last commit
  elif git -C "$root" commit -q --only -m "skogai-core: journal" -- "${paths[@]}" >&2; then
    ran+=("committed journal")
  else
    ran+=("journal commit (failed)")
  fi
fi

if skogai_on "stage_on_$event"; then
  git -C "$root" add -A
  ran+=("git add -A")
fi

if skogai_on "commit_on_$event" && [[ -n $(git -C "$root" status --porcelain) ]]; then
  if wt -C "$root" step commit >&2; then
    ran+=("wt step commit")
  else
    ran+=("wt step commit (failed)")
  fi
fi

# --no-remove keeps the worktree the session is running in. wt's output goes
# to stderr so it never lands in Claude's context, and a failed merge (say, on
# the default branch) is logged instead of failing the hook.
if skogai_on "merge_on_$event"; then
  if wt -C "$root" merge --no-remove >&2; then
    ran+=("wt merge")
  else
    ran+=("wt merge (failed)")
  fi
fi

(IFS=,; printf '%s' "${ran[*]}" | sed 's/,/, /g')
