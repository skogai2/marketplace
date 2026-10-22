#!/usr/bin/env bash
# @describe skogai main runner: one `argc` for every registered command file
#
# `argc <name> ...` runs the argc script registered as <name>, from the directory
# argc was called in. `argc register <file> <name>` adds one, `argc sync` rebuilds.
# this file is a template: `sync` writes ~/Argcfile.sh from it plus one recipe
# per registered command, so argc finds it from anywhere under ~.
# @meta require-tools argc,jq
# @meta binname argc
# @env ARGC_COMMANDS                             registry dir, default ~/.config/argc/commands
# @env ARGC_MAIN                                 the generated main file, default ~/Argcfile.sh

# shellcheck disable=SC2154,SC2016 # argc_* are assigned by --argc-eval; generated code stays quoted
set -euo pipefail

COMMANDS="${ARGC_COMMANDS:-${XDG_CONFIG_HOME:-$HOME/.config}/argc/commands}"
MAIN="${ARGC_MAIN:-$HOME/Argcfile.sh}"
TEMPLATE="$(realpath "${BASH_SOURCE[0]}")"
# >>> template
# <<< template

# @cmd register an argc script as `argc <name>`, then sync
# @arg file!                           the argc script, linked, not copied
# @arg name!                           lowercase, one segment
register() {
    [[ "$argc_name" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "bad name: $argc_name" >&2; return 2; }
    case "$argc_name" in register | unregister | ls | sync | help) echo "reserved: $argc_name" >&2; return 2 ;; esac
    local file
    file="$(cd "${ARGC_PWD:-$PWD}" && realpath -e "$argc_file")"
    argc --argc-export "$file" >/dev/null
    mkdir -p "$COMMANDS"
    ln -sfn "$file" "$COMMANDS/$argc_name.sh"
    sync
}

# @cmd remove a registered command, then sync
# @arg name![`_choice_command`]
unregister() {
    rm -f "$COMMANDS/$argc_name.sh"
    sync
}

# @cmd registered commands and where they point
ls() {
    local f
    for f in "$COMMANDS"/*.sh; do
        [[ -e "$f" || -L "$f" ]] || continue
        printf '%-12s %s\n' "$(basename "$f" .sh)" "$(readlink "$f")"
    done
}

# @cmd rebuild the main file from the template and the registry
#
# a command whose file is gone or doesn't parse is skipped with a warning.
sync() {
    local out f name describe
    out="$(mktemp)"
    {
        sed '/^# >>> template$/q' "$TEMPLATE"
        printf 'TEMPLATE=%q\n' "$TEMPLATE"
        sed -n '/^# <<< template$/,$p' "$TEMPLATE" | sed '/^eval "\$(argc --argc-eval/d'
        for f in "$COMMANDS"/*.sh; do
            [[ -e "$f" ]] || { [[ -L "$f" ]] && echo "skip  $(basename "$f"): $(readlink "$f") is gone" >&2; continue; }
            name="$(basename "$f" .sh)"
            describe="$(argc --argc-export "$f" 2>/dev/null | jq -r '(.describe // "") | split("\n")[0] // ""')" ||
                { echo "skip  $name: does not parse" >&2; continue; }
            printf '\n# @cmd %s\n# @arg args~[?`_choice_delegate`]\n%s() { _delegate %s "${argc_args[@]}"; }\n' \
                "${describe:-$name}" "$name" "$name"
        done
        printf '\neval "$(argc --argc-eval "$0" "$@")"\n'
    } >"$out"
    argc --argc-export "$out" >/dev/null
    mv "$out" "$MAIN"
    echo "wrote $MAIN" >&2
}

# registered command <name> with the rest of the args, from the caller's directory
_delegate() {
    local name="$1"
    shift
    (cd "${ARGC_PWD:-$PWD}" && argc --argc-run "$COMMANDS/$name.sh" "$@")
}

# completion for a forwarded command: ask its own script, drop argc's color field
_choice_delegate() {
    local name="$argc__cmd_fn"
    argc --argc-compgen generic "$COMMANDS/$name.sh" "$name" "${argc__args[@]:argc__cmd_arg_index+1}" |
        awk -F '\t' '$1 ~ /^__argc_value=/ { print tolower($1); next } $1 ~ /^__argc_/ { print $1; next } $2 ~ /^\/color:/ { print $1 (NF >= 3 ? "\t" $3 : ""); next } { print }'
}

_choice_command() {
    local f
    for f in "$COMMANDS"/*.sh; do [[ -e "$f" || -L "$f" ]] && basename "$f" .sh; done
}

eval "$(argc --argc-eval "$0" "$@")"
