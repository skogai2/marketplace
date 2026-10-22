#!/usr/bin/env bash
# @describe skogai core: config across layers, and the modules skogai is made of
#
# a module is a directory with a module.md: frontmatter says what it is, which
# argc script is its command, which files it offers and its config defaults.
# modules are found installed (local .skogai/modules, then global), then in
# the sources on $SKOGAI_MODULE_PATH. the first one by a name wins.
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

# @cmd read and write key/value config across system, global, local and module layers
#
# fold order, later wins: module.md `config:` defaults, system, global, local,
# module.local.md overrides, --file layers, then SKOGAI_* env.
# a module's keys are mounted under its name: runner's `model` is `runner.model`.
config() { :; }

# @cmd print the resolved value of a key; a list prints one item per line
# @flag --show-origin  also print which layer the value came from
# @option --file*  a markdown file whose frontmatter is a layer, with its .local.md after it
# @option --scope  mount --file keys under this section
# @arg key![`_choice_key`]
config::get() {
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
# @option --module[`_choice_installed`]  write this installed module's module.local.md
# @option --file  write this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![?`_choice_key`]
# @arg value!
config::set() {
    local file key
    if _md_target; then
        key="$(_file_key "$argc_key")" || exit 2
        [[ -f $file ]] || printf -- '---\n{}\n---\n' >"$file"
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
# @option --module[`_choice_installed`]  remove from this installed module's module.local.md
# @option --file  remove from this file's .local.md frontmatter instead
# @option --scope  the section --file keys are mounted under
# @arg key![`_choice_target_key`]
config::unset() {
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
config::list() {
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
config::env() {
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
config::files() {
    local layer file name dir
    while IFS=$'\t' read -r name layer dir; do
        _present "module:$name" "$dir/module.md"
    done < <(_modules)
    for layer in system global local; do
        _present "$layer" "$(_layer_file "$layer")"
    done
    while IFS=$'\t' read -r name layer dir; do
        [[ $layer == source ]] || _present "module:$name" "$dir/module.local.md"
    done < <(_modules)
    while IFS= read -r file; do
        _present file "$file"
    done < <(_file_layers)
}

# @cmd find, show, install and scaffold modules
module() { :; }

# @cmd every module by name: where it was found and what it is
module::ls() {
    local name layer dir
    while IFS=$'\t' read -r name layer dir; do
        printf '%-12s %-7s %s\n' "$name" "$layer" "$(_field "$dir/module.md" .description)"
    done < <(_modules)
}

# @cmd a module's manifest, where it lives, and what it is missing
# @arg name![`_choice_module`]
module::show() {
    local dir layer
    IFS=$'\t' read -r _ layer dir < <(_module "$argc_name") || { echo "no module: $argc_name" >&2; exit 1; }
    printf '%s\t%s\n' "$layer" "$dir"
    yq --front-matter=extract . "$dir/module.md"
    _missing "$dir"
}

# @cmd path of a module's argc script; exits 1 if it has none
# @arg name![`_choice_module`]
module::command() {
    local dir cmd
    IFS=$'\t' read -r _ _ dir < <(_module "$argc_name") || exit 1
    cmd="$(_field "$dir/module.md" .command)"
    [[ -n $cmd && -f $dir/$cmd ]] || exit 1
    echo "$dir/$cmd"
}

# @cmd the env a module's command runs with, as export lines
#
# SKOGAI_MODULE, SKOGAI_MODULE_DIR, SKOGAI_LOCAL_DIR and SKOGAI_CONFIG_DIR
# (both absolute), and the module's own resolved keys: runner.model is
# SKOGAI_RUNNER_MODEL.
# @arg name![`_choice_module`]
module::env() {
    local dir key value
    IFS=$'\t' read -r _ _ dir < <(_module "$argc_name") || exit 1
    printf 'export SKOGAI_MODULE=%q\n' "$argc_name"
    printf 'export SKOGAI_MODULE_DIR=%q\n' "$dir"
    printf 'export SKOGAI_LOCAL_DIR=%q\n' "$(_local_dir)"
    printf 'export SKOGAI_CONFIG_DIR=%q\n' "$GLOBAL_DIR"
    while IFS=$'\t' read -r key value _; do
        [[ $key == "$argc_name".* ]] || continue
        printf 'export %s=%q\n' "$(_env_name "$key")" "${value//$SEP/$'\n'}"
    done < <(_resolve)
}

# @cmd copy a module into .skogai/modules, or the global dir. prints the plan unless --apply
#
# copies module.md, its command and its `files:`. a file already there and
# different is kept and reported; `skogai module diff` shows how.
# exit 1 when there is something to copy and --apply was not given.
# @arg source![`_choice_source`]  a module name from the sources, or a path to a module dir
# @option --to[local|global]  where to install, default core.module.install
# @flag --apply  copy the files
module::add() {
    local src name to dest rel status todo=0
    src="$(_source "$argc_source")" || { echo "no module source: $argc_source" >&2; exit 2; }
    name="$(basename "$src")"
    to="${argc_to:-$(_get core.module.install local)}"
    dest="$(_install_dir "$to")/$name"
    [[ $src != "$dest" ]] || { echo "already installed: $dest" >&2; exit 0; }
    echo "$name: $src -> $dest" >&2
    while IFS= read -r rel; do
        if [[ ! -e $dest/$rel ]]; then
            status=add todo=1
        elif cmp -s "$src/$rel" "$dest/$rel"; then
            status=same
        else
            status=keep
        fi
        printf '%-5s %s\n' "$status" "$rel"
        if [[ $status == add && ${argc_apply:-} == 1 ]]; then
            mkdir -p "$(dirname "$dest/$rel")"
            cp -p "$src/$rel" "$dest/$rel"
        fi
    done < <(_module_files "$src")
    _missing "$src" >&2
    [[ $todo == 0 || ${argc_apply:-} == 1 ]] || exit 1
}

# @cmd diff an installed module against its source
# @arg name![`_choice_installed`]
module::diff() {
    local dir src rel rc=0
    IFS=$'\t' read -r _ _ dir < <(_module "$argc_name") || exit 1
    src="$(_source "$argc_name")" || { echo "no source for $argc_name" >&2; exit 2; }
    while IFS= read -r rel; do
        diff -u --label "source/$rel" --label "installed/$rel" "$src/$rel" "$dir/$rel" 2>/dev/null || rc=1
    done < <(_module_files "$src")
    return "$rc"
}

# @cmd scaffold a new module from core's templates/module
# @arg name!  lowercase, one segment
# @arg description  what it is, one line
# @option --to[local|global]  where to create it, default core.module.install
module::new() {
    [[ $argc_name =~ ^[a-z][a-z0-9]*$ ]] || { echo "bad name: $argc_name" >&2; exit 2; }
    local to dest core tpl f
    to="${argc_to:-$(_get core.module.install local)}"
    dest="$(_install_dir "$to")/$argc_name"
    [[ ! -e $dest ]] || { echo "exists: $dest" >&2; exit 2; }
    IFS=$'\t' read -r _ _ core < <(_module core)
    tpl="$core/templates/module"
    mkdir -p "$dest"
    for f in "$tpl"/*; do
        NAME="$argc_name" DESC="${argc_description:-}" \
            awk '{ gsub(/\{\{name\}\}/, ENVIRON["NAME"]); gsub(/\{\{description\}\}/, ENVIRON["DESC"]); print }' \
            "$f" >"$dest/$(basename "$f")"
        [[ ! -x $f ]] || chmod +x "$dest/$(basename "$f")"
        echo "wrote $dest/$(basename "$f")" >&2
    done
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

# a module dir to install from: a path, or a name looked up in the sources only
_source() {
    local p
    if [[ $1 == */* || $1 == . ]]; then
        p="$(cd "${ARGC_PWD:-$PWD}" && realpath -e "$1")" && [[ -f $p/module.md ]] && echo "$p"
        return
    fi
    _module_bases | while IFS=$'\t' read -r layer p; do
        [[ $layer == source && -f $p/$1/module.md ]] && { realpath "$p/$1"; break; }
    done | grep .
}

# files a module consists of, relative to its dir: module.md, its command, its `files:`
_module_files() {
    local dir="$1" f
    {
        echo module.md
        _field "$dir/module.md" .command
        while IFS= read -r f; do
            [[ -n $f ]] || continue
            if [[ -d $dir/$f ]]; then (cd "$dir" && find "${f%/}" -type f); else echo "$f"; fi
        done < <(_field "$dir/module.md" '.files[]')
    } | grep . | sort -u
}

# tools and modules a module dir needs and can't find, one line each
_missing() {
    local t r
    while IFS= read -r t; do
        [[ -z $t ]] || command -v "$t" >/dev/null || echo "missing tool: $t"
    done < <(_field "$1/module.md" '.tools[]')
    while IFS= read -r r; do
        [[ -z $r ]] || _module "$r" >/dev/null || echo "missing module: $r (skogai module add $r)"
    done < <(_field "$1/module.md" '.requires[]')
}

# a frontmatter field, empty if missing
_field() { yq --front-matter=extract "$2 // \"\"" "$1" 2>/dev/null || true; }

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
        local dir
        IFS=$'\t' read -r _ _ dir < <(_module "$argc_module") || { echo "no module: $argc_module" >&2; exit 2; }
        file="$dir/module.local.md"
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
        [[ -z $name || $layer == source ]] || _fold "$dir/module.local.md" "$name" .config "module:$name.local"
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

# every resolved key; choices for get and set, described by value when completing
_choice_key() {
    if [[ ${ARGC_COMPGEN:-0} == 1 ]]; then _resolve | cut -f1,2 | tr "$SEP" ' '; else _resolve | cut -f1; fi
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
_choice_installed() { _modules | awk -F'\t' '$2 != "source" { print $1 }'; }
_choice_source() { _module_bases | awk -F'\t' '$1 == "source" { print $2 }' | while read -r p; do ls "$p"; done; }

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
