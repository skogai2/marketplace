#!/usr/bin/env bash
# Runs the git steps switched on for one event, from the git root, and prints
# what ran as a comma-separated list for the log.
# Usage: git-steps.sh <EVENT> <root>   (EVENT: STOP or USER_PROMPT_SUBMIT)
# Switches, all off unless true, run in this order (dash's `skogai config`
# keys, with the env names they map to, <EVENT> without its `_`):
#   stage.on-<event>   SKOGAI_STAGE_ON<EVENT>    `git add -A`
#   commit.on-<event>  SKOGAI_COMMIT_ON<EVENT>   `wt step commit` (skipped when the tree is clean)
#   merge.on-<event>   SKOGAI_MERGE_ON<EVENT>    `wt merge --no-remove`
# Read with `skogai config list` from the git root, so its base, global and
# local layers apply. Without a working `skogai` on PATH, the env vars alone.
set -euo pipefail

event=$1 root=$2
on=on-$(tr '[:upper:]_' '[:lower:]-' <<<"$event")
config=$(cd "$root" && skogai config list 2>/dev/null) || config=

# switch <step>: the resolved value of <step>.on-<event>.
switch() {
  local var=SKOGAI_${1^^}_ON${event//_/}
  if [[ -n $config ]]; then
    sed -n "s/^$1\.$on=//p" <<<"$config"
  else
    echo "${!var:-}"
  fi
}
ran=()

if [[ $(switch stage) == true ]]; then
  git -C "$root" add -A
  ran+=("git add -A")
fi

if [[ $(switch commit) == true && -n $(git -C "$root" status --porcelain) ]]; then
  if wt -C "$root" step commit >&2; then
    ran+=("wt step commit")
  else
    ran+=("wt step commit (failed)")
  fi
fi

# --no-remove keeps the worktree the session is running in. wt's output goes
# to stderr so it never lands in Claude's context, and a failed merge (say, on
# the default branch) is logged instead of failing the hook.
if [[ $(switch merge) == true ]]; then
  if wt -C "$root" merge --no-remove >&2; then
    ran+=("wt merge")
  else
    ran+=("wt merge (failed)")
  fi
fi

(IFS=,; printf '%s' "${ran[*]}" | sed 's/,/, /g')
