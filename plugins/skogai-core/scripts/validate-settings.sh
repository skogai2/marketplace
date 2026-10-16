#!/usr/bin/env bash
# Checks a skogai-core settings file the way scripts/settings.sh and
# hooks/register.ts read it. Exits 1 on errors; warnings don't fail it.
# Usage: validate-settings.sh [path]   (default: .claude/skogai-core.local.md
#                                       at the git root)
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
SKOGAI_SETTINGS=${1:-}
. "$(dirname "$0")/settings.sh"
file=$SKOGAI_SETTINGS

errors=0
error() { echo "error: $*"; errors=$((errors + 1)); }
warn() { echo "warning: $*"; }

if [[ ! -f $file ]]; then
  echo "$file: not found. That's fine: skogai-core runs with defaults."
  exit 0
fi
[[ -r $file ]] || { error "$file is not readable"; exit 1; }

# The frontmatter must open on line 1 and close with its own ---.
if [[ $(head -n1 "$file") != --- ]]; then
  error "first line must be --- (settings.sh reads nothing otherwise)"
elif [[ $(grep -c '^---$' "$file") -lt 2 ]]; then
  error "no closing --- after the frontmatter"
fi
((errors == 0)) || exit 1

frontmatter=$(awk 'NR == 1 { next } $0 == "---" { exit } { print }' "$file")
keys=$(grep -oE '^[A-Za-z_][A-Za-z0-9_]*:' <<<"$frontmatter" | tr -d : || true)
for key in $keys; do
  case $key in
    enabled | events | log_path | status_line) ;;
    *) warn "unknown key '$key' is ignored" ;;
  esac
done
[[ $(sort <<<"$keys" | uniq -d) ]] && error "duplicate keys: $(sort <<<"$keys" | uniq -d | paste -sd' ')"

for key in enabled status_line; do
  value=$(skogai_setting "$key")
  [[ -z $value || $value == true || $value == false ]] || error "$key must be true or false, got '$value'"
done

known="SessionStart UserPromptSubmit PreToolUse PostToolUse PostToolUseFailure Notification
  SubagentStart SubagentStop PreCompact PostCompact Stop StopFailure SessionEnd"
events=$(skogai_setting events)
for pattern in $events; do
  matched=
  for event in $known; do
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ $event == $pattern ]] && matched=1
  done
  [[ $matched ]] || warn "events: '$pattern' matches no event skogai-core acts upon"
done
if [[ $events ]]; then
  for event in UserPromptSubmit PostToolUse PostToolUseFailure; do
    skogai_logs "$event" || warn "events leaves out $event, so journal entries lose what it records"
  done
fi

log_path=$(skogai_setting log_path)
case $log_path in
  /*) error "log_path must be relative to the git root, got '$log_path'" ;;
  *..*) error "log_path must stay inside the git root, got '$log_path'" ;;
esac

if ((errors > 0)); then
  echo "$file: $errors error(s)"
  exit 1
fi
echo "$file: ok"
echo "  enabled=$SKOGAI_ENABLED status_line=$(skogai_setting status_line)"
echo "  events=${SKOGAI_EVENTS:-all}"
echo "  log=$SKOGAI_LOG"
