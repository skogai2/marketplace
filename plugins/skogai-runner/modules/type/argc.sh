#!/usr/bin/env bash
# @describe type: instance schemas, every module's schema/<x>.json checked against its instances
#
# a module that requires type offers schema/<x>.json and globs its instances
# with config <module>.schema.<x>, relative to the local dir; `<key>` in the
# glob is the module's own resolved <module>.<key>.
# @meta require-tools yq,ajv
# @meta binname skogai type

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail
shopt -s globstar

: "${SKOGAI_MODULE_DIR:?run me as \`skogai type\`}"
AJV=(--spec=draft2020 --strict=true)
# field separator of _schemas: not whitespace, so an empty field survives `read`
FS=$'\x1f'

# @cmd every instance against its schema; one line per problem: module<TAB>path<TAB>message
#
# exit 1 on any problem: an instance that does not match, frontmatter that
# does not parse, a schema that does not compile, a schema with no glob.
# @arg module*[`_choice_typed`]  default every module that requires type
check() {
    local m schema glob problem f rc=0 tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    while IFS="$FS" read -r m schema glob problem; do
        [[ -z $problem ]] || { printf '%s\t%s\t%s\n' "$m" "$schema" "$problem"; rc=1; continue; }
        while IFS= read -r f; do
            _validate "$m" "$schema" "$f" "$tmp/data.json" || rc=1
        done < <(_instances "$glob")
    done < <(_schemas)
    return "$rc"
}

# @cmd each schema: module<TAB>schema<TAB>glob<TAB>instances
#
# a schema with no glob goes to stderr as module<TAB>path<TAB>message, exit 1.
# @arg module*[`_choice_typed`]  default every module that requires type
ls() {
    local m schema glob problem rc=0
    while IFS="$FS" read -r m schema glob problem; do
        [[ -z $problem ]] || { printf '%s\t%s\t%s\n' "$m" "$schema" "$problem" >&2; rc=1; continue; }
        printf '%s\t%s\t%s\t%s\n' "$m" "$(basename "$schema" .json)" "$glob" "$(_instances "$glob" | grep -c . || true)"
    done < <(_schemas)
    return "$rc"
}

# "module FS schema path FS filled glob FS problem" for each schema of the
# given modules, the problem empty unless there is no glob
_schemas() {
    local m dir schema x glob mods=("${argc_module[@]}")
    [[ ${#mods[@]} -gt 0 ]] || mapfile -t mods < <(_typed)
    for m in "${mods[@]}"; do
        dir="$(_dir "$m")" || { printf '%s\x1f-\x1f\x1fno module\n' "$m"; continue; }
        for schema in "$dir"/schema/*.json; do
            [[ -f $schema ]] || continue
            x="$(basename "$schema" .json)"
            if ! glob="$(skogai config get "$m.schema.$x" 2>/dev/null)" || [[ -z $glob ]]; then
                printf '%s\x1f%s\x1f\x1fno glob: config %s.schema.%s\n' "$m" "$schema" "$m" "$x"
            elif ! glob="$(_fill "$m" "$glob")"; then
                printf '%s\x1f%s\x1f\x1f%s\n' "$m" "$schema" "$glob"
            else
                printf '%s\x1f%s\x1f%s\x1f\n' "$m" "$schema" "$glob"
            fi
        done
    done
}

# the glob with each `<key>` replaced by the module's <module>.<key>; on a
# missing key prints the problem and returns 1
_fill() {
    local rest="$2" out="" v
    while [[ $rest =~ ^([^\<]*)\<([a-z0-9.-]+)\>(.*)$ ]]; do
        v="$(skogai config get "$1.${BASH_REMATCH[2]}" 2>/dev/null)" || { echo "no config $1.${BASH_REMATCH[2]} for <${BASH_REMATCH[2]}>"; return 1; }
        out+="${BASH_REMATCH[1]}$v"
        rest="${BASH_REMATCH[3]}"
    done
    echo "$out$rest"
}

# files the glob matches, relative to the local dir, sorted
_instances() {
    local f
    while IFS= read -r f; do
        [[ -f $f ]] && echo "$f"
    done < <(compgen -G "$SKOGAI_LOCAL_DIR/$1" | sort || true)
}

# one instance's frontmatter against a schema, problems as lines
_validate() {
    local m="$1" schema="$2" f="$3" json="$4" err line
    if ! err="$(yq --front-matter=extract -o json 'select(document_index == 0)' "$f" 2>&1 >"$json")"; then
        printf '%s\t%s\tfrontmatter: %s\n' "$m" "$f" "${err//$'\n'/ }"
        return 1
    fi
    err="$(ajv validate "${AJV[@]}" --all-errors --errors=json -s "$schema" -d "$json" 2>&1 >/dev/null)" && return 0
    while IFS= read -r line; do
        printf '%s\t%s\t%s\n' "$m" "$f" "$line"
    done < <(tail -n +2 <<<"$err" | yq -p json '.[] | (.instancePath + " " + .message) | sub("^ "; "")' 2>/dev/null ||
        tr '\n' ' ' <<<"$err" | sed 's/ *$/\n/')
    return 1
}

# the dir a module is found in
_dir() { skogai module show "$1" 2>/dev/null | awk -F'\t' 'NR == 1 && NF == 2 { print $2; f = 1 } END { exit !f }'; }

# every module that requires type
_typed() {
    local m dir
    while read -r m _; do
        dir="$(_dir "$m")" || continue
        yq --front-matter=extract '.requires // [] | .[]' "$dir/module.md" | grep -qx type && echo "$m"
    done < <(skogai module ls)
    return 0
}

_choice_typed() { _typed; }

eval "$(argc --argc-eval "$0" "$@")"
