#!/usr/bin/env bash
# Reads skogai-core's mod settings: the `userConfig` options in
# .claude-plugin/plugin.json, which Claude Code exports to every hook as
# CLAUDE_PLUGIN_OPTION_<KEY>. Set them with `/plugin configure skogai-core`
# or in /config. The fallbacks here match plugin.json's defaults, for runs
# outside Claude Code (tests). Source it with $root set (the git root); it sets:
#   SKOGAI_ENABLED  true or false: the master switch
#   SKOGAI_EVENTS   event names (globs allowed) to log; * or empty logs every one
#   SKOGAI_LOG      absolute path of the event log
#   SKOGAI_JOURNAL  absolute path of the turn journal
#   SKOGAI_STATE    absolute path of the state directory

# skogai_opt <key> <default>: the option's value, or the default when unset.
skogai_opt() {
  local var="CLAUDE_PLUGIN_OPTION_${1^^}"
  printf '%s' "${!var-$2}"
}

# skogai_on <key>: whether a boolean option is true (they all default to false).
skogai_on() { [[ $(skogai_opt "$1" false) == true ]]; }

# skogai_path <key> <default>: the option as an absolute path, relative ones
# resolved against the git root.
skogai_path() {
  local p
  p=$(skogai_opt "$1" "$2")
  [[ $p == /* ]] || p="$root/$p"
  printf '%s' "$p"
}

SKOGAI_ENABLED=false
skogai_on enabled && SKOGAI_ENABLED=true
SKOGAI_EVENTS=$(skogai_opt events '*')
SKOGAI_LOG=$(skogai_path log_path .skogai/logs/skogai-core/log.jsonl)
SKOGAI_JOURNAL=$(skogai_path journal_path .skogai/journal.md)
SKOGAI_STATE=$(skogai_path state_dir .skogai/tmp)

# skogai_logs <event>: whether `events` lets this event into the log.
skogai_logs() {
  [[ -z $SKOGAI_EVENTS ]] && return 0
  local pattern patterns
  read -ra patterns <<<"$SKOGAI_EVENTS" # read, not $SKOGAI_EVENTS, so * isn't expanded
  for pattern in "${patterns[@]}"; do
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ $1 == $pattern ]] && return 0
  done
  return 1
}
