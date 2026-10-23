#!/usr/bin/env bash
# @describe skogai config: read and write key/value config across system, global, local and module layers
#
# fold order, later wins: module.md `config:` defaults, system, global, local,
# module.local.md overrides, --file layers, then SKOGAI_* env.
# a module's keys are mounted under its name: runner's `model` is `runner.model`.
#
# the config half of skogai-runner's core module, copied as is; modules are
# found the way core finds them, for their `config:` defaults and module.local.md.
# @meta require-tools git,yq
# @meta binname skogai
# @env SKOGAI_SYSTEM_DIR=/etc/skogai  dir of the system layer config
# @env SKOGAI_CONFIG_DIR  dir of the global layer, default ~/.config/skogai
# @env SKOGAI_LOCAL_DIR=.skogai  dir of the local layer; relative is from the git root, or pwd
# @env SKOGAI_MODULE_PATH  colon-separated dirs of module sources, default the one this module sits in

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

SELF="$(realpath "${BASH_SOURCE[0]}")"
GLOBAL_DIR="${SKOGAI_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skogai}"
MODULE_PATH="${SKOGAI_MODULE_PATH:-$(dirname "$(dirname "$SELF")")}"

# joins the items of a list value; `get` prints one item per line
SEP=$'\x1f'

# @cmd print the resolved value of a key; a list prints one item per line
# @flag --show-origin  also print which layer the value came from
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount --file keys under this section
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

# @cmd set a key in the local layer, the global one, a module's module.local.md or a --file's .local.md
# @flag --global  write to the global layer instead of local
# @option --module[`_choice_module`]  write this module's module.local.md
# @option --file  write this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![?`_choice_key`]
# @arg value!
set() {
    local file key
    if _md_target; then
        key="$(_file_key "$argc_key")" || exit 2
        [[ -f $file ]] || { mkdir -p "$(dirname "$file")" && printf -- '---\n{}\n---\n' >"$file"; }
        K="$key" V="$argc_value" \
            yq -i --front-matter=process 'setpath(strenv(K) | split("."); strenv(V) | from_yaml)' "$file"
        return
    fi
    file="$(_target_file)"
    mkdir -p "$(dirname "$file")"
    git config -f "$file" "$argc_key" "$argc_value"
}

# @cmd remove a key from the local layer, the global one, a module's module.local.md or a --file's .local.md
# @flag --global  remove from the global layer instead of local
# @option --module[`_choice_module`]  remove from this module's module.local.md
# @option --file  remove from this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![`_choice_target_key`]
unset() {
    local file key
    if _md_target; then
        key="$(_file_key "$argc_key")" || exit 2
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
    local layer file name dir
    while IFS=$'\t' read -r name layer dir; do
        _present "module:$name" "$dir/module.md"
    done < <(_modules)
    for layer in system global local; do
        _present "$layer" "$(_layer_file "$layer")"
    done
    while IFS=$'\t' read -r name layer dir; do
        _present "module:$name" "$(_module_local_md "$name" "$layer" "$dir")"
    done < <(_modules)
    while IFS= read -r file; do
        _present file "$file"
    done < <(_file_layers)
}

# the resolved "key<TAB>value<TAB>origin" line of a key; exit 1 if unset
_line() {
    local resolved
    resolved="$(_resolve)" || return 2
    awk -F'\t' -v k="$1" '$1 == k { print; f = 1 } END { exit !f }' <<<"$resolved"
}

# a resolved value, or $2 if unset
_get() { _line "$1" | cut -f2 | grep . || echo "${2:-}"; }

_local_dir() {
    local dir="${SKOGAI_LOCAL_DIR:-.skogai}"
    [[ $dir == /* ]] || dir="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/$dir"
    echo "$dir"
}

_install_dir() {
    case "$1" in
    local) echo "$(_local_dir)/modules" ;;
    global) echo "$GLOBAL_DIR/modules" ;;
    *) echo "bad --to: $1" >&2; return 2 ;;
    esac
}

# "layer<TAB>dir" for every place modules are looked for, in order
_module_bases() {
    local p
    printf 'local\t%s\n' "$(_install_dir local)"
    printf 'global\t%s\n' "$(_install_dir global)"
    IFS=: read -ra p <<<"$MODULE_PATH"
    for p in "${p[@]}"; do [[ -z $p ]] || printf 'source\t%s\n' "$p"; done
}

# "name<TAB>layer<TAB>dir" for every module, the first by a name wins
_modules() {
    local -A seen
    local layer base d name
    while IFS=$'\t' read -r layer base; do
        for d in "$base"/*/; do
            [[ -f $d/module.md ]] || continue
            d="$(realpath "$d")"
            name="$(basename "$d")"
            [[ -z ${seen[$name]:-} ]] || continue
            seen[$name]=1
            printf '%s\t%s\t%s\n' "$name" "$layer" "$d"
        done
    done < <(_module_bases)
}

_module() { _modules | awk -F'\t' -v n="$1" '$1 == n { print; f = 1 } END { exit !f }'; }

_present() { printf '%s\t%s\t%s\n' "$1" "$2" "$([[ -f $2 ]] && echo present || echo missing)"; }

# layers in fold order, later wins: system, global, local
_layer_file() {
    case "$1" in
    system) echo "$SKOGAI_SYSTEM_DIR/config" ;;
    global) echo "$GLOBAL_DIR/config" ;;
    local) echo "$(_local_dir)/config" ;;
    esac
}

# x.md -> x.local.md
_local_md() { echo "${1%.md}.local.md"; }

# a module's overrides: beside its module.md when installed; a source one's
# go in the local install dir, never into the source
_module_local_md() {
    if [[ $2 == source ]]; then echo "$(_install_dir local)/$1/module.local.md"; else echo "$3/module.local.md"; fi
}

# --file layers in fold order: each x.md, then its x.local.md
_file_layers() {
    local f
    for f in "${argc_file[@]}"; do
        echo "$f"
        _local_md "$f"
    done
}

# set/unset into a markdown file: sets `file`, and `argc_scope` for --module
_md_target() {
    if [[ -n ${argc_module:-} ]]; then
        local layer dir
        IFS=$'\t' read -r _ layer dir < <(_module "$argc_module") || { echo "no module: $argc_module" >&2; exit 2; }
        file="$(_module_local_md "$argc_module" "$layer" "$dir")"
        argc_scope="$argc_module"
        MD_ROOT=config
        return 0
    fi
    [[ -n ${argc_file:-} ]] || return 1
    file="$(_local_md "$argc_file")"
}

# `.` is a relation, `-` is part of a name: stage.on-stop -> SKOGAI_STAGE_ONSTOP
_env_name() {
    local k="${1^^}"
    k="${k//-/}"
    echo "SKOGAI_${k//./_}"
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

# prints "key<TAB>value<TAB>origin" for every resolved key
_resolve() {
    local -A val origin
    local layer file key value env tag name dir fm entry
    _fold() { # file scope root origin
        [[ -f $1 ]] || return 0
        fm="$(_frontmatter "$1" "$2" "$3")" || exit 2
        while IFS=$'\t' read -r key tag value; do
            [[ -n $key ]] || continue
            if [[ $tag == '!!null' ]]; then
                builtin unset "val[$key]" "origin[$key]"
            else
                val[$key]="$value"
                origin[$key]="$4"
            fi
        done <<<"$fm"
    }
    local mods
    mods="$(_modules)"
    while IFS=$'\t' read -r name layer dir; do
        [[ -z $name ]] || _fold "$dir/module.md" "$name" .config "module:$name"
    done <<<"$mods"
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
    while IFS=$'\t' read -r name layer dir; do
        [[ -z $name ]] || _fold "$(_module_local_md "$name" "$layer" "$dir")" "$name" .config "module:$name.local"
    done <<<"$mods"
    while IFS= read -r file; do
        _fold "$file" "${argc_scope:-}" . "file:$file"
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

# every resolved key, only --module's own if given; choices for get and set,
# described by value when completing
_choice_key() {
    local keys
    keys="$(_resolve | awk -F'\t' -v m="${argc_module:-}" 'm == "" || index($1, m ".") == 1')"
    if [[ ${ARGC_COMPGEN:-0} == 1 ]]; then cut -f1,2 <<<"$keys" | tr "$SEP" ' '; else cut -f1 <<<"$keys"; fi
}

# keys present in the layer set/unset write to; choices for unset
_choice_target_key() {
    local file
    if _md_target 2>/dev/null; then
        if [[ -f $file ]]; then _frontmatter "$file" "${argc_scope:-}" "${MD_ROOT:+.$MD_ROOT}" | cut -f1; fi
    else
        file="$(_target_file)"
        if [[ -f $file ]]; then git config -f "$file" --name-only --list; fi
    fi
}

_choice_module() { _modules | cut -f1; }

# the frontmatter path of a key in a markdown layer: the key minus its scope,
# under `config.` for a module's module.local.md
_file_key() {
    local key="$1" scope="${argc_scope:-}"
    if [[ -n $scope ]]; then
        [[ $key == "$scope".* ]] || { echo "key $key is outside $scope" >&2; return 2; }
        key="${key#"$scope".}"
    fi
    [[ $key =~ ^[^.]+(\.[^.]+)*$ ]] || { echo "bad key: $1" >&2; return 2; }
    echo "${MD_ROOT:+$MD_ROOT.}$key"
}

eval "$(argc --argc-eval "$0" "$@")"
