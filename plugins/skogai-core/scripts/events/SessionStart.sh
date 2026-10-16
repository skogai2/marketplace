#!/usr/bin/env bash
# SessionStart: write the current state to .skogai/tmp/ (see write-state.sh),
# then log it.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

action=
if root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  . "$here/../settings.sh"
  [[ $SKOGAI_ENABLED == true ]] || exit 0
  "$here/../write-state.sh" "$root"
  action="wrote .skogai/tmp"
fi
exec "$here/../append-json.sh" "$action" <<<"$input"
