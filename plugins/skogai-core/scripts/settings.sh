#!/usr/bin/env bash
# Reads this project's settings from .claude/skogai-core.local.md at the git
# root (copy examples/skogai-core.local.md there to start). Source it with
# $root set (and SKOGAI_SETTINGS to read another file); it sets:
#   SKOGAI_ENABLED  false only when the file says `enabled: false`
#   SKOGAI_EVENTS   event names (globs allowed) to log; empty logs every one
#   SKOGAI_LOG      absolute path of the event log (`log_path`, relative to
#                   the git root)
# With no file, everything is on and the log is at the default path.
# register.ts reads the same file for `log_path`, `enabled` and `status_line`.

SKOGAI_SETTINGS=${SKOGAI_SETTINGS:-$root/.claude/skogai-core.local.md}

# The resolved settings as key=value lines, one per list item. dash's
# `skogai config` folds its base, global and local layers, then this file and
# its .local.md, then env (SKOGAI_SKOGAICORE_<KEY>). Without a `skogai` that
# knows --file, only the .local.md is read, by the awk below.
SKOGAI_RESOLVED=$(cd "$root" 2>/dev/null &&
  skogai config list --file "${SKOGAI_SETTINGS%.local.md}.md" --scope skogai-core 2>/dev/null) ||
  SKOGAI_RESOLVED=

# skogai_setting <key>: the key's value, `_` read as `-`. A list, inline
# (`[a, "b"]`) or as `- item` lines, comes out space-separated.
skogai_setting() {
  if [[ -n $SKOGAI_RESOLVED ]]; then
    sed -n "s/^skogai-core\.${1//_/-}=//p" <<<"$SKOGAI_RESOLVED" | paste -sd' '
    return
  fi
  [[ -f $SKOGAI_SETTINGS ]] || return 0
  awk -v k="$1" -v k2="${1//_/-}" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function unquote(s) { s = trim(s); if (s ~ /^".*"$/ || s ~ /^'\''.*'\''$/) s = substr(s, 2, length(s) - 2); return s }
    function nocomment(s) { sub(/[ \t]+#.*$/, "", s); return s }
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    inlist && /^[ \t]*- / { sub(/^[ \t]*- /, ""); out = out " " unquote(nocomment($0)); next }
    inlist { exit }
    index($0, k ":") == 1 || index($0, k2 ":") == 1 {
      v = trim(nocomment(substr($0, index($0, ":") + 1)))
      if (v == "") { inlist = 1; next }
      if (v ~ /^\[.*\]$/) {
        n = split(substr(v, 2, length(v) - 2), a, ",")
        for (i = 1; i <= n; i++) if (trim(a[i]) != "") out = out " " unquote(a[i])
      } else out = unquote(v)
      exit
    }
    END { out = trim(out); if (out == "~" || out == "null") out = ""; print out }
  ' "$SKOGAI_SETTINGS"
}

SKOGAI_ENABLED=true
[[ $(skogai_setting enabled) == false ]] && SKOGAI_ENABLED=false
SKOGAI_EVENTS=$(skogai_setting events)
SKOGAI_LOG="$root/$(skogai_setting log_path)"
[[ $SKOGAI_LOG == "$root/" ]] && SKOGAI_LOG="$root/.skogai/logs/skogai-core/log.jsonl"

# skogai_logs <event>: whether the settings let this event into the log.
skogai_logs() {
  [[ -z $SKOGAI_EVENTS ]] && return 0
  local pattern
  for pattern in $SKOGAI_EVENTS; do
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ $1 == $pattern ]] && return 0
  done
  return 1
}
