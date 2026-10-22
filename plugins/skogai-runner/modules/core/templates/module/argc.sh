#!/usr/bin/env bash
# @describe {{description}}
# @meta binname skogai {{name}}

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

# @cmd say hello, with {{name}}.greeting from skogai config
# @arg who=world
hello() {
    printf '%s, %s\n' "$(skogai config get "{{name}}.greeting" 2>/dev/null || echo hello)" "$argc_who"
}

eval "$(argc --argc-eval "$0" "$@")"
