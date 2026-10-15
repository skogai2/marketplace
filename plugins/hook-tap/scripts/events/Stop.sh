#!/usr/bin/env bash
# Stop: append the turn to .skogai/journal.md at the git root, run the git
# steps switched on for turn end (see git-steps.sh), and log it. Staging is on
# unless SKOGAI_STAGE_ON_STOP is set to something other than true. The prompt and the tool uses come
# from this turn's rows in the log, matched by prompt_id.
set -euo pipefail

here=$(dirname "$0")
input=$(cat)
cwd=$(jq -r '.cwd' <<<"$input")

# Outside a git repo there is nothing to stage, so only log.
if ! root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null); then
  exec "$here/../append-json.sh" <<<"$input"
fi

log="$root/.skogai/logs/hook-tap/log.jsonl"
journal="$root/.skogai/journal.md"
prompt_id=$(jq -r '.prompt_id // empty' <<<"$input")

# grep narrows the log to this turn before jq parses anything.
rows='[]'
if [[ -n $prompt_id && -f $log ]]; then
  rows=$(grep -F "$prompt_id" "$log" |
    jq -sc --arg p "$prompt_id" 'map(select(.input.prompt_id == $p and .input.agent_id == null))')
fi

mkdir -p "$(dirname "$journal")"
jq -rn --argjson rows "$rows" --argjson stop "$input" --arg root "$root" \
  --arg ts "$(date +'%Y-%m-%d %H:%M')" '
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
  | join("\n\n") + "\n"' >>"$journal"

export SKOGAI_STAGE_ON_STOP=${SKOGAI_STAGE_ON_STOP:-true}
ran=$("$here/../git-steps.sh" STOP "$root")
exec "$here/../append-json.sh" "journal entry${ran:+, $ran}" <<<"$input"
