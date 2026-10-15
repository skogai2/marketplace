#!/usr/bin/env bash
# UserPromptSubmit: run the git steps switched on for turn start (see
# git-steps.sh), then log it.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

ran=
if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  ran=$("$here/../git-steps.sh" USER_PROMPT_SUBMIT "$root")
fi
exec "$here/../append-json.sh" "$ran" <<<"$input"
