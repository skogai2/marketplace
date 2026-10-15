#!/usr/bin/env bash
# Appends one row to the event log for an event we acted upon.
# Usage: <hook stdin json> | append-json.sh [what we did]
set -euo pipefail

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
cwd=${cwd:-$PWD}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
log="$root/.skogai/logs/skogai-core/log.jsonl"
mkdir -p "$(dirname "$log")"

# Hooks can fire in parallel (PreToolUse for parallel tool calls), so hold a
# lock on the log while the row is written.
exec 9>>"$log"
flock 9
jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)" --arg action "${1:-}" \
  '{ts: $ts, event: .hook_event_name}
   + (if $action == "" then {} else {action: $action} end)
   + {input: .}' <<<"$input" >&9
