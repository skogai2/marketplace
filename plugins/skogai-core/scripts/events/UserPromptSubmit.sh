#!/usr/bin/env bash
# UserPromptSubmit: run the git steps switched on for turn start (see
# git-steps.sh), write the resulting state to .skogai/tmp/ (see
# write-state.sh), then log it.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

ran=
if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  . "$here/../settings.sh"
  [[ $SKOGAI_ENABLED == true ]] || exit 0
  ran=$("$here/../git-steps.sh" USER_PROMPT_SUBMIT "$root")
  "$here/../write-state.sh" "$root"
  ran+="${ran:+, }wrote .skogai/tmp"
fi
exec "$here/../append-json.sh" "$ran" <<<"$input"
