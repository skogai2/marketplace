#!/usr/bin/env bash
# Tests the scripts without a Claude session: writes sample hook rows with
# append-json.sh into a throwaway git repo, runs Stop.sh, and checks the log,
# the journal entry and what got staged. Usage: tests/run.sh
set -euo pipefail

scripts=$(cd "$(dirname "$0")/../scripts" && pwd)
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
git -C "$repo" init -q
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

row UserPromptSubmit $other '{"prompt": "an older turn"}' | "$scripts/append-json.sh"
row UserPromptSubmit $p '{"prompt": "hello\n\nsecond line\n"}' | "$scripts/append-json.sh"
row PostToolUse $p '{"tool_name": "Bash", "tool_input": {"command": "echo hi\necho more"}}' | "$scripts/append-json.sh"
row PostToolUse $p '{"tool_name": "Bash", "tool_input": {"command": "ls"}, "agent_id": "sub1"}' | "$scripts/append-json.sh"
row PostToolUseFailure $p "{\"tool_name\": \"Read\", \"tool_input\": {\"file_path\": \"$repo/src/a.txt\"}}" | "$scripts/append-json.sh"
row PostToolUse $other '{"tool_name": "Bash", "tool_input": {"command": "not this turn"}}' | "$scripts/append-json.sh"
row Stop $p '{"last_assistant_message": "done"}' | SKOGAI_STAGE_ON_STOP=true "$scripts/events/Stop.sh"

log="$repo/.skogai/logs/skogai-core/log.jsonl"
check "log is at the git root, one row per event" \
  "UserPromptSubmit UserPromptSubmit PostToolUse PostToolUse PostToolUseFailure PostToolUse Stop" \
  "$(jq -r .event "$log" | paste -sd' ')"
check "only Stop has an action" "journal entry, git add -A, wrote .skogai/tmp" "$(jq -r '.action // empty' "$log")"

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
check "journal and work are staged, log is not" \
  "$(printf '.skogai/journal.md\nsrc/a.txt')" \
  "$(git -C "$repo" diff --cached --name-only | grep -v '^.skogai/logs/')"

# Settings in .claude/skogai-core.local.md: a filtered list and another log path.
mkdir -p "$repo/.claude"
printf -- '---\nevents:\n  - "Post*"\nlog_path: other.jsonl # moved\n---\nnotes\n' >"$repo/.claude/skogai-core.local.md"
row PreToolUse $p | "$scripts/append-json.sh"
row PostToolUse $p | "$scripts/append-json.sh" ran
check "settings: only listed events, at log_path" "PostToolUse ran" \
  "$(jq -r '"\(.event) \(.action)"' "$repo/other.jsonl")"
check "settings: validator accepts them" 0 \
  "$(cd "$repo" && "$scripts/validate-settings.sh" >/dev/null; echo $?)"

printf -- '---\nenabled: false\n---\n' >"$repo/.claude/skogai-core.local.md"
before=$(wc -l <"$log")
row UserPromptSubmit $p | "$scripts/events/UserPromptSubmit.sh"
row Stop $p '{"last_assistant_message": "x"}' | "$scripts/events/Stop.sh"
check "settings: enabled: false logs and journals nothing" "$before 1" \
  "$(wc -l <"$log") $(grep -c '^## ' "$repo/.skogai/journal.md")"

printf -- '---\nenabled: maybe\nlog_path: /abs\n---\n' >"$repo/.claude/skogai-core.local.md"
check "settings: validator rejects bad values" 1 \
  "$(cd "$repo" && "$scripts/validate-settings.sh" >/dev/null; echo $?)"

# With a `skogai` that knows --file, a global git-config layer reaches the
# plugin too. Skipped without one.
if (cd "$repo" && skogai config list --file x.md >/dev/null 2>&1); then
  rm "$repo/.claude/skogai-core.local.md"
  global=$(mktemp)
  printf '[skogai-core]\n\tlog-path = global.jsonl\n' >"$global"
  row PreToolUse $p | SKOGAI_GLOBAL_CONFIG=$global "$scripts/append-json.sh"
  rm "$global"
  check "settings: skogai config's global layer sets log-path" PreToolUse \
    "$(jq -r .event "$repo/global.jsonl" 2>/dev/null)"
else
  echo "skip settings through skogai config (no skogai with --file on PATH)"
fi

exit $fail
