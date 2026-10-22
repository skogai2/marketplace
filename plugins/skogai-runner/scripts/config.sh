#!/usr/bin/env bash
# @describe read and write key/value config across system, global and local layers
# @meta require-tools git
# @env SKOGAI_SYSTEM_DIR=/etc/skogai  dir of the system layer config
# @env SKOGAI_CONFIG_DIR=/home/skogix/.config/skogai  dir of the global layer config
# @env SKOGAI_LOCAL_DIR=.skogai  dir of the local layer config; relative is from the git root, or pwd
set -euo pipefail

# joins the items of a list value; `get` prints one item per line
SEP=$'\x1f'

# layers in fold order, later wins: system, global, local
_layer_file() {
    local dir
    case "$1" in
    system) dir="$SKOGAI_SYSTEM_DIR" ;;
    global) dir="$SKOGAI_CONFIG_DIR" ;;
    local)
        dir="$SKOGAI_LOCAL_DIR"
        [[ $dir == /* ]] || dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/$dir"
        ;;
    esac
    echo "$dir/config"
}

# x.md -> x.local.md
_local_md() { echo "${1%.md}.local.md"; }

# --file layers in fold order: each x.md, then its x.local.md
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
    echo "SKOGAI_${k//./_}"
}

# a frontmatter file as "key<TAB>tag<TAB>value" lines: nested maps flatten to
# dotted keys, under --scope if given, with `_` read as `-`. a list is one
# value, its items joined by SEP.
_frontmatter() {
    SEP="$SEP" SCOPE="${argc_scope:-}" yq --front-matter=extract '
        select(document_index == 0) | select(tag == "!!map") | .. |
        select(tag == "!!seq" or (tag != "!!map" and (parent | tag) != "!!seq")) |
        [ ((strenv(SCOPE) | select(. != "") | [.]) // []) + path | join(".") | downcase | sub("_"; "-"),
          tag,
          (select(tag == "!!seq") | map(tostring) | join(strenv(SEP))) // tostring
        ] | join("\t")' "$1"
}

# prints "key<TAB>value<TAB>origin" for every resolved key
_resolve() {
    local -A val origin
    local layer file key value env tag
    for layer in system global local; do
        file="$(_layer_file "$layer")"
        [[ -f $file ]] || continue
        while IFS= read -r -d '' entry; do
            key="${entry%%$'\n'*}"
            value="${entry#*$'\n'}"
            [[ $entry == *$'\n'* ]] || value=""
            val[$key]="$value"
            origin[$key]="$layer"
        done < <(git config -f "$file" --list -z)
    done
    local fm
    while IFS= read -r file; do
        [[ -f $file ]] || continue
        fm="$(_frontmatter "$file")" || exit 2
        while IFS=$'\t' read -r key tag value; do
            [[ -n $key ]] || continue
            if [[ $tag == '!!null' ]]; then
                builtin unset "val[$key]" "origin[$key]"
            else
                val[$key]="$value"
                origin[$key]="file:$file"
            fi
        done <<<"$fm"
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

_target_file() {
    if [[ ${argc_global:-} == 1 ]]; then _layer_file global; else _layer_file local; fi
}

# every resolved key; choices for get and set, described by value when completing
_choice_key() {
    if [[ ${ARGC_COMPGEN:-0} == 1 ]]; then _resolve | cut -f1,2 | tr "$SEP" ' '; else _resolve | cut -f1; fi
}

# keys present in the layer set/unset write to; choices for unset
_choice_target_key() {
    local file
    if [[ -n ${argc_file:-} ]]; then
        file="$(_local_md "$argc_file")"
        if [[ -f $file ]]; then _frontmatter "$file" | cut -f1; fi
    else
        file="$(_target_file)"
        if [[ -f $file ]]; then git config -f "$file" --name-only --list; fi
    fi
}

# the frontmatter path of a key in a --file layer: the key minus --scope
_file_key() {
    local key="$1" scope="${argc_scope:-}"
    if [[ -n $scope ]]; then
        [[ $key == "$scope".* ]] || { echo "key $key is outside --scope $scope" >&2; return 2; }
        key="${key#"$scope".}"
    fi
    [[ $key =~ ^[^.]+(\.[^.]+)*$ ]] || { echo "bad key: $1" >&2; return 2; }
    echo "$key"
}

# @cmd print the resolved value of a key; a list prints one item per line
# @flag --show-origin  also print which layer the value came from
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount --file keys under this section
# @arg key![`_choice_key`]
get() {
    local line
    line="$(_resolve | awk -F'\t' -v k="$argc_key" '$1 == k')" || exit 2
    if [[ ${argc_show_origin:-} == 1 ]]; then
        printf '%s\t%s\n' "$(cut -f3 <<<"$line")" "$(cut -f2 <<<"$line" | tr "$SEP" ' ')"
    else
        cut -f2 <<<"$line" | tr "$SEP" '\n'
    fi
}

# @cmd set a key in the local layer, or the global one, or a --file's .local.md
# @flag --global  write to the global layer instead of local
# @option --file  write this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![?`_choice_key`]
# @arg value!
set() {
    local file key
    if [[ -n ${argc_file:-} ]]; then
        key="$(_file_key "$argc_key")" || exit 2
        file="$(_local_md "$argc_file")"
        [[ -f $file ]] || printf -- '---\n{}\n---\n' >"$file"
        K="$key" V="$argc_value" \
            yq -i --front-matter=process 'setpath(strenv(K) | split("."); strenv(V) | from_yaml)' "$file"
        return
    fi
    file="$(_target_file)"
    mkdir -p "$(dirname "$file")"
    git config -f "$file" "$argc_key" "$argc_value"
}

# @cmd remove a key from the local layer, or the global one, or a --file's .local.md
# @flag --global  remove from the global layer instead of local
# @option --file  remove from this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![`_choice_target_key`]
unset() {
    local file key
    if [[ -n ${argc_file:-} ]]; then
        key="$(_file_key "$argc_key")" || exit 2
        file="$(_local_md "$argc_file")"
        [[ -f $file ]] || exit 1
        K="$key" \
            yq -i --front-matter=process 'delpaths([strenv(K) | split(".")])' "$file"
        return
    fi
    file="$(_target_file)"
    [[ -f $file ]] || exit 1
    git config -f "$file" --unset-all "$argc_key" || exit 1
}

# @cmd print every resolved key as key=value; a list prints one line per item
# @flag --show-origin  prefix each line with the layer it came from
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount --file keys under this section
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
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount --file keys under this section
env() {
    local key value origin resolved
    resolved="$(_resolve)" || exit 2
    [[ -n $resolved ]] || return 0
    while IFS=$'\t' read -r key value origin; do
        printf 'export %s=%q\n' "$(_env_name "$key")" "${value//$SEP/$'\n'}"
    done <<<"$resolved"
}

# @cmd print the path of each layer file, and whether it exists
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  accepted for symmetry with get and list; unused
files() {
    local layer file
    for layer in system global local; do
        file="$(_layer_file "$layer")"
        printf '%s\t%s\t%s\n' "$layer" "$file" "$([[ -f $file ]] && echo present || echo missing)"
    done
    while IFS= read -r file; do
        printf '%s\t%s\t%s\n' file "$file" "$([[ -f $file ]] && echo present || echo missing)"
    done < <(_file_layers)
}

eval "$(argc --argc-eval "$0" "$@")"
