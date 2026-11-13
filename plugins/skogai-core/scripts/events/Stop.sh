#!/usr/bin/env bash
# Stop: if `journal` is on, append the turn to the journal and commit only
# that file (the log never is); run the git steps switched on for turn end
# (see git-steps.sh); write the state files if `write_state` is on (see
# write-state.sh); and log it. The prompt and the tool uses come from this
# turn's rows in the log, matched by prompt_id.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

# Outside a git repo there is nothing to stage, so only log.
if ! root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  exec "$here/../append-json.sh" <<<"$input"
fi

. "$here/../settings.sh"
[[ $SKOGAI_ENABLED == true ]] || exit 0
log=$SKOGAI_LOG
journal=$SKOGAI_JOURNAL
prompt_id=$(jq -r '.prompt_id // empty' <<<"$input")

# The turn's rows sit at the end of the log, after its UserPromptSubmit row, so
# read backwards and stop there instead of scanning the whole log. The rows and
# the stop input reach jq as a file and stdin: as arguments a long turn exceeds
# the kernel's per-argument limit.
turn_rows() {
  [[ -n $prompt_id && -f $log ]] || return 0
  tac "$log" |
    awk -v p="$prompt_id" 'index($0, p) { print; if (index($0, "\"event\":\"UserPromptSubmit\"")) exit }' |
    tac |
    jq -c --arg p "$prompt_id" 'select(.input.prompt_id == $p and .input.agent_id == null)' || true
}

journal_entry() {
mkdir -p "$(dirname "$journal")"
jq -r --slurpfile rows <(turn_rows) --arg root "$root" \
  --arg ts "$(date +'%Y-%m-%d %H:%M')" '
  . as $stop |
  def first_line: split("\n")[0] | if length > 120 then .[:120] + "…" else . end;
  def rel: if type == "string" and startswith($root + "/") then .[($root | length) + 1:] else tostring end;
  def quote: split("\n") | map(if . == "" then ">" else "> " + . end) | join("\n");
  # One line per tool use. File tools show the path relative to the git root.
  def action:
    .input.tool_name as $n | (.input.tool_input // {}) as $i |
    (if $n == "Bash" then "Bash: `\($i.command // "" | first_line)`"
     elif $i.file_path then "\($n) `\($i.file_path | rel)`"
     elif $i.path then "\($n) `\($i.path | rel)`"
     else ([$i[]? | strings][0]) as $a | if $a then "\($n): \($a | first_line)" else $n end
     end) + (if .event == "PostToolUseFailure" then " (failed)" else "" end);
  ([$rows[] | select(.event == "UserPromptSubmit") | .input.prompt][0] // "") as $prompt |
  [$rows[] | select(.event == "PostToolUse" or .event == "PostToolUseFailure") | action] as $actions |
  [ "## \($ts) · turn \($stop.prompt_id // "unknown" | .[:8])",
    "**User**", ($prompt | gsub("^\\s+|\\s+$"; "") | quote),
    "**Assistant**", (($stop.last_assistant_message // "") | gsub("^\\s+|\\s+$"; "") | if . == "" then "_(no text)_" else . end) ]
  + (if ($actions | length) > 0 then ["**Actions**", ($actions | map("- " + .) | join("\n"))] else [] end)
  | join("\n\n") + "\n"' <<<"$input" >>"$journal"
}

done=()
if skogai_on journal; then
  journal_entry
  done+=("journal entry")
  ran=$("$here/../git-steps.sh" stop "$root" "$journal")
else
  ran=$("$here/../git-steps.sh" stop "$root")
fi
[[ -n $ran ]] && done+=("$ran")
if skogai_on write_state; then
  "$here/../write-state.sh" "$root" "$SKOGAI_STATE"
  done+=("wrote state")
fi
action=$(IFS=,; printf '%s' "${done[*]}" | sed 's/, */, /g')
exec "$here/../append-json.sh" "$action" <<<"$input"
