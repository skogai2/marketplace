#!/usr/bin/env bash
# UserPromptSubmit: run the git steps switched on for a prompt (see
# git-steps.sh), write the state files if `write_state` is on (see
# write-state.sh), then log it.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

ran=
if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  . "$here/../settings.sh"
  [[ $SKOGAI_ENABLED == true ]] || exit 0
  ran=$("$here/../git-steps.sh" prompt "$root")
  if skogai_on write_state; then
    "$here/../write-state.sh" "$root" "$SKOGAI_STATE"
    ran+="${ran:+, }wrote state"
  fi
fi
exec "$here/../append-json.sh" "$ran" <<<"$input"
