#!/usr/bin/env bash
# @describe {{description}}
# @meta binname skogai {{name}}

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai {{name}}\`}"

# @cmd say hello, with {{name}}.greeting from skogai config
# @arg who=world
hello() {
    printf '%s, %s\n' "${SKOGAI_{{NAME}}_GREETING:-hello}" "$argc_who"
}

eval "$(argc --argc-eval "$0" "$@")"
