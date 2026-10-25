#!/usr/bin/env bash
# @describe markdown frontmatter as key/value config, extracted from skogai-runner's core module (~/.local/src/skogai-runner)
#
# each --file X.md is a layer, with its X.local.md after it; later wins, then
# <PREFIX>_* env. nested maps flatten to dotted keys, `_` reads as `-`, a list
# is one value whose items `get` prints one per line, and a null removes a key
# an earlier layer set. writes go to the .local.md, never the committed file.
# @meta require-tools yq
# @meta binname frontmatter
# @env FRONTMATTER_ENV_PREFIX=SKOGAI  env override names: stage.on-stop -> SKOGAI_STAGE_ONSTOP

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

# joins the items of a list value; `get` prints one item per line
SEP=$'\x1f'

# @cmd print the resolved value of a key; a list prints one item per line
# @flag --show-origin  also print which layer the value came from
# @option --file+  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount keys under this section
# @option --root  read only this map of the frontmatter, e.g. config
# @arg key![`_choice_key`]
get() {
    local line
    line="$(_line "$argc_key")" || exit $?
    if [[ ${argc_show_origin:-} == 1 ]]; then
        printf '%s\t%s\n' "$(cut -f3 <<<"$line")" "$(cut -f2 <<<"$line" | tr "$SEP" ' ')"
    else
        cut -f2 <<<"$line" | tr "$SEP" '\n'
    fi
}

# @cmd set a key in a file's .local.md frontmatter
# @option --file!  the markdown file whose .local.md is written
# @option --scope  the section keys are mounted under
# @option --root  write under this map of the frontmatter, e.g. config
# @arg key![?`_choice_key`]
# @arg value!
set() {
    local file key
    file="$(_local_md "$argc_file")"
    key="$(_file_key "$argc_key")" || exit 2
    [[ -f $file ]] || { mkdir -p "$(dirname "$file")" && printf -- '---\n{}\n---\n' >"$file"; }
    K="$key" V="$argc_value" \
        yq -i --front-matter=process 'setpath(strenv(K) | split("."); strenv(V) | from_yaml)' "$file"
}

# @cmd remove a key from a file's .local.md frontmatter
# @option --file!  the markdown file whose .local.md is written
# @option --scope  the section keys are mounted under
# @option --root  remove under this map of the frontmatter, e.g. config
# @arg key![`_choice_target_key`]
unset() {
    local file key
    file="$(_local_md "$argc_file")"
    key="$(_file_key "$argc_key")" || exit 2
    [[ -f $file ]] || exit 1
    K="$key" \
        yq -i --front-matter=process 'delpaths([strenv(K) | split(".")])' "$file"
}

# @cmd print every resolved key as key=value; a list prints one line per item
# @flag --show-origin  prefix each line with the layer it came from
# @option --file+  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount keys under this section
# @option --root  read only this map of the frontmatter, e.g. config
list() {
    local key value origin item resolved
    resolved="$(_resolve)" || exit 2
    [[ -n $resolved ]] || return 0
    while IFS=$'\t' read -r key value origin; do
        while IFS= read -r -d "$SEP" item; do
            if [[ ${argc_show_origin:-} == 1 ]]; then
                printf '%s\t%s=%s\n' "$origin" "$key" "$item"
            else
                printf '%s=%s\n' "$key" "$item"
            fi
        done <<<"$value$SEP"
    done <<<"$resolved"
}

# @cmd print the resolved config as export lines; a list's items are newline-separated
# @option --file+  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount keys under this section
# @option --root  read only this map of the frontmatter, e.g. config
env() {
    local key value origin resolved
    resolved="$(_resolve)" || exit 2
    [[ -n $resolved ]] || return 0
    while IFS=$'\t' read -r key value origin; do
        printf 'export %s=%q\n' "$(_env_name "$key")" "${value//$SEP/$'\n'}"
    done <<<"$resolved"
}

# @cmd print the path of each layer file, and whether it exists
# @option --file+  a markdown file whose frontmatter is a layer, with its .local.md after it
files() {
    local file
    while IFS= read -r file; do
        printf '%s\t%s\n' "$file" "$([[ -f $file ]] && echo present || echo missing)"
    done < <(_file_layers)
}

# the resolved "key<TAB>value<TAB>origin" line of a key; 1 if unset
_line() {
    local resolved
    resolved="$(_resolve)" || exit 2
    awk -F'\t' -v k="$1" '$1 == k { print; found = 1 } END { exit !found }' <<<"$resolved"
}

# x.md -> x.local.md
_local_md() { echo "${1%.md}.local.md"; }

# layers in fold order: each x.md, then its x.local.md
_file_layers() {
    local f
    for f in "${argc_file[@]}"; do
        echo "$f"
        _local_md "$f"
    done
}

# `.` is a relation, `-` is part of a name: stage.on-stop -> SKOGAI_STAGE_ONSTOP
_env_name() {
    local k="${1^^}"
    k="${k//-/}"
    echo "${FRONTMATTER_ENV_PREFIX:-SKOGAI}_${k//./_}"
}

# a frontmatter file as "key<TAB>tag<TAB>value" lines: nested maps flatten to
# dotted keys, under the scope ($2, or --scope) if given, with `_` read as `-`.
# $3 picks the map to read, default the whole frontmatter. a list is one value,
# its items joined by SEP.
_frontmatter() {
    yq --front-matter=extract "select(document_index == 0) | ${3:-.} // {}" "$1" |
        SEP="$SEP" SCOPE="${2-${argc_scope:-}}" yq '
        select(tag == "!!map") | .. |
        select(tag == "!!seq" or (tag != "!!map" and (parent | tag) != "!!seq")) |
        [ ((strenv(SCOPE) | select(. != "") | [.]) // []) + path | join(".") | downcase | sub("_"; "-"),
          tag,
          (select(tag == "!!seq") | map(tostring) | join(strenv(SEP))) // tostring
        ] | join("\t")'
}

# --root as a yq path, empty for the whole frontmatter
_root() { echo "${argc_root:+.$argc_root}"; }

# prints "key<TAB>value<TAB>origin" for every resolved key
_resolve() {
    local -A val origin
    local file key value env tag fm
    _fold() { # file origin
        [[ -f $1 ]] || return 0
        fm="$(_frontmatter "$1" "${argc_scope:-}" "$(_root)")" || exit 2
        while IFS=$'\t' read -r key tag value; do
            [[ -n $key ]] || continue
            if [[ $tag == '!!null' ]]; then
                builtin unset "val[$key]" "origin[$key]"
            else
                val[$key]="$value"
                origin[$key]="$2"
            fi
        done <<<"$fm"
    }
    while IFS= read -r file; do
        _fold "$file" "file:$file"
    done < <(_file_layers)
    for key in "${!val[@]}"; do
        env="$(_env_name "$key")"
        if [[ -n ${!env+x} ]]; then
            val[$key]="${!env}"
            origin[$key]="env:$env"
        fi
    done
    for key in "${!val[@]}"; do
        printf '%s\t%s\t%s\n' "$key" "${val[$key]}" "${origin[$key]}"
    done | sort
}

# every resolved key; choices for get and set, described by value when completing
_choice_key() {
    [[ -n ${argc_file:-} ]] || return 0
    local keys
    keys="$(_resolve)"
    if [[ ${ARGC_COMPGEN:-0} == 1 ]]; then cut -f1,2 <<<"$keys" | tr "$SEP" ' '; else cut -f1 <<<"$keys"; fi
}

# keys present in the .local.md set/unset write to; choices for unset
_choice_target_key() {
    [[ -n ${argc_file:-} ]] || return 0
    local file
    file="$(_local_md "$argc_file")"
    if [[ -f $file ]]; then _frontmatter "$file" "${argc_scope:-}" "$(_root)" | cut -f1; fi
}

# the frontmatter path of a key: the key minus its scope, under --root if given
_file_key() {
    local key="$1" scope="${argc_scope:-}"
    if [[ -n $scope ]]; then
        [[ $key == "$scope".* ]] || { echo "key $key is outside $scope" >&2; return 2; }
        key="${key#"$scope".}"
    fi
    [[ $key =~ ^[^.]+(\.[^.]+)*$ ]] || { echo "bad key: $1" >&2; return 2; }
    echo "${argc_root:+$argc_root.}$key"
}

eval "$(argc --argc-eval "$0" "$@")"
