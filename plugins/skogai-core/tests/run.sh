#!/usr/bin/env bash
# Tests the scripts without a Claude session: writes sample hook rows with
# append-json.sh into a throwaway git repo, runs Stop.sh, and checks the log,
# the journal entry and what got staged. Usage: tests/run.sh
set -euo pipefail

scripts=$(cd "$(dirname "$0")/../scripts" && pwd)
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q
git -C "$repo" config user.name test
git -C "$repo" config user.email test@example.com
mkdir -p "$repo/src"
echo hi >"$repo/src/a.txt"

fail=0
check() { # check <name> <expected> <actual>
  if [[ $2 == "$3" ]]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    diff <(echo "$2") <(echo "$3") | sed 's/^/     /' || true
    fail=1
  fi
}

# One hook row: event name, prompt_id, then extra fields as a JSON object.
row() { jq -nc --arg e "$1" --arg p "$2" --arg cwd "$repo/src" --argjson x "${3:-{\}}" \
  '{session_id: "s1", cwd: $cwd, prompt_id: $p, hook_event_name: $e} + $x'; }

p=11111111-aaaa-bbbb-cccc-000000000000
other=22222222-aaaa-bbbb-cccc-000000000000

# Off by default: with no mod settings set, nothing is logged or journaled.
row UserPromptSubmit $p '{"prompt": "ignored"}' | "$scripts/events/UserPromptSubmit.sh"
row Stop $p '{"last_assistant_message": "x"}' | "$scripts/events/Stop.sh"
check "defaults: no log, no journal, no state" "" \
  "$(ls -A "$repo/.skogai" 2>/dev/null)"

# Mod settings as Claude Code exports them.
export CLAUDE_PLUGIN_OPTION_ENABLED=true CLAUDE_PLUGIN_OPTION_JOURNAL=true \
  CLAUDE_PLUGIN_OPTION_WRITE_STATE=true

row UserPromptSubmit $other '{"prompt": "an older turn"}' | "$scripts/append-json.sh"
row UserPromptSubmit $p '{"prompt": "hello\n\nsecond line\n"}' | "$scripts/append-json.sh"
row PostToolUse $p '{"tool_name": "Bash", "tool_input": {"command": "echo hi\necho more"}}' | "$scripts/append-json.sh"
row PostToolUse $p '{"tool_name": "Bash", "tool_input": {"command": "ls"}, "agent_id": "sub1"}' | "$scripts/append-json.sh"
row PostToolUseFailure $p "{\"tool_name\": \"Read\", \"tool_input\": {\"file_path\": \"$repo/src/a.txt\"}}" | "$scripts/append-json.sh"
row PostToolUse $other '{"tool_name": "Bash", "tool_input": {"command": "not this turn"}}' | "$scripts/append-json.sh"
row Stop $p '{"last_assistant_message": "done"}' | CLAUDE_PLUGIN_OPTION_STAGE_ON_STOP=true "$scripts/events/Stop.sh"

log="$repo/.skogai/logs/skogai-core/log.jsonl"
check "log is at the git root, one row per event" \
  "UserPromptSubmit UserPromptSubmit PostToolUse PostToolUse PostToolUseFailure PostToolUse Stop" \
  "$(jq -r .event "$log" | paste -sd' ')"
check "only Stop has an action" "journal entry, committed journal, git add -A, wrote state" "$(jq -r '.action // empty' "$log")"

expected="## <ts> · turn 11111111

**User**

> hello
>
> second line

**Assistant**

done

**Actions**

- Bash: \`echo hi\`
- Read \`src/a.txt\` (failed)"
check "journal entry at the git root" "$expected" \
  "$(sed -E '1s/^## .{16} ·/## <ts> ·/' "$repo/.skogai/journal.md")"
check "only the journal is committed, never the log" \
  ".skogai/journal.md" \
  "$(git -C "$repo" show --name-only --format= HEAD)"
check "work is staged, not committed" "src/a.txt" \
  "$(git -C "$repo" diff --cached --name-only | grep -v '^.skogai/logs/')"
check "state files written" "git-diff git-diff-cached wt-step-diff" \
  "$(cd "$repo/.skogai/tmp" && ls | paste -sd' ')"

# events filters, log_path moves the log.
CLAUDE_PLUGIN_OPTION_EVENTS='Post*' CLAUDE_PLUGIN_OPTION_LOG_PATH=other.jsonl \
  bash -c 'row() { jq -nc --arg e "$1" --arg cwd "$2" "{cwd: \$cwd, hook_event_name: \$e}"; }
    row PreToolUse "$1" | "$0/append-json.sh"
    row PostToolUse "$1" | "$0/append-json.sh" ran' "$scripts" "$repo/src"
check "settings: only listed events, at log_path" "PostToolUse ran" \
  "$(jq -r '"\(.event) \(.action)"' "$repo/other.jsonl")"

# journal off: no entry, nothing committed.
commits=$(git -C "$repo" rev-list --count HEAD)
row Stop $p '{"last_assistant_message": "x"}' | CLAUDE_PLUGIN_OPTION_JOURNAL=false "$scripts/events/Stop.sh"
check "settings: journal off writes and commits nothing" "1 $commits" \
  "$(grep -c '^## ' "$repo/.skogai/journal.md") $(git -C "$repo" rev-list --count HEAD)"

# enabled off: nothing at all.
before=$(wc -l <"$log")
row UserPromptSubmit $p | CLAUDE_PLUGIN_OPTION_ENABLED=false "$scripts/events/UserPromptSubmit.sh"
row Stop $p '{"last_assistant_message": "x"}' | CLAUDE_PLUGIN_OPTION_ENABLED=false "$scripts/events/Stop.sh"
check "settings: enabled false logs and journals nothing" "$before 1" \
  "$(wc -l <"$log") $(grep -c '^## ' "$repo/.skogai/journal.md")"

exit $fail
