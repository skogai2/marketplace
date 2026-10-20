#!/usr/bin/env bash
# @describe skogai command runner: typed io for handing work to agents
#
# every agent call is `prompt + files -> json matching a schema`.
# pure by default: only `--apply` changes existing files, scaffolds only create new ones.
# @meta require-tools jq,yq,git,claude
# @meta dotenv
# @meta binname argc
# @env SKOGAI_MODEL=sonnet                         default model for agent calls
# @env ARGC_DOCS=~/.local/src/argc/docs           argc docs handed to `improve`
# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

ROOT="$PWD"
PLUGINS="$ROOT/plugins"
SCHEMAS="$PLUGINS/skogai-runner/schemas"
WORKORDERS="$ROOT/.skogai/workorders"
LOGS="$ROOT/.skogai/logs/argc"

# @cmd send a prompt and files to an agent, print its typed output
#
# the prompt comes from --prompt or stdin. files are inlined as
# <file path="..."> blocks, so the agent needs no tools to read them.
# with --schema stdout is the json object, without it plain text.
# @option -p --prompt                  prompt text, read from stdin if omitted
# @option -f --file* <FILE>            file to inline
# @option -s --schema[?`_choice_schema`] schema name or path for the output
# @option -m --model                   model, defaults to $SKOGAI_MODEL
# @option -t --tools                   tools the agent may use, none if omitted
# @option -a --allow*                  allowed tool patterns, e.g. "Bash(git log *)"
# @option    --plugin-dir* <DIR>       plugin to load into the agent
# @flag      --raw                     print the full result envelope
# @alias s
send() {
    local prompt="${argc_prompt:-$(cat)}"
    _compose "$prompt" "${argc_file[@]}" |
        _agent "${argc_schema:-}" "${argc_model:-$SKOGAI_MODEL}" "${argc_tools:-}" "${argc_raw:-}"
}

# @cmd ask an agent to edit files, print the patch. pure unless --apply
#
# the agent returns whole files (schema `edit`), the patch is derived
# here with `git diff`, so a bad hunk header can never break it.
# @arg request~                        what to change
# @option -f --file* <FILE>            files to hand over, default Argcfile.sh and the runner skill
# @option -m --model                   model, defaults to $SKOGAI_MODEL
# @flag      --apply                   apply the patch to the tree
# @alias i
improve() {
    local files=("${argc_file[@]}")
    [[ ${#files[@]} -gt 0 ]] || files=(Argcfile.sh plugins/skogai-runner/skills/argc/SKILL.md)
    local docs="${ARGC_DOCS/#\~/$HOME}"
    local ctx=()
    [[ -f "$docs/specification.md" ]] && ctx+=("$docs/specification.md")
    [[ -f "$docs/command-runner.md" ]] && ctx+=("$docs/command-runner.md")

    local prompt
    prompt="$(printf '%s\n\n%s\n%s\n' "${argc_request[*]}" \
        "return every file you change in full, paths relative to the repo root." \
        "only these files may change: ${files[*]}")"

    local out patch
    out="$(_compose "$prompt" "${files[@]}" "${ctx[@]}" | _agent edit "${argc_model:-$SKOGAI_MODEL}" "" "")"
    patch="$(_edit_to_patch "$out" "${files[@]}")"
    jq -r '.summary' <<<"$out" >&2
    if [[ -z "$patch" ]]; then
        echo "empty patch" >&2
        return 0
    fi
    if [[ -n "${argc_apply:-}" ]]; then
        git apply --check <<<"$patch"
        git apply <<<"$patch"
        git diff --stat -- "${files[@]}" >&2
    else
        printf '%s\n' "$patch"
        return 1
    fi
}

# @cmd workorders: one bounded question, gathered inputs, checkable output
wo() { :; }

# @cmd scaffold a workorder
# @arg name!                           kebab-case name
# @option -s --schema[?`_choice_schema`] output schema, default answer
# @option -f --file* <FILE>            input files
# @option -t --tools                   tools the worker may use
wo::new() {
    local path="$WORKORDERS/$argc_name.md"
    [[ ! -e "$path" ]] || { echo "exists: $path" >&2; return 2; }
    mkdir -p "$WORKORDERS"
    {
        echo "---"
        echo "type: workorder"
        echo "title: $argc_name"
        echo "schema: ${argc_schema:-answer}"
        echo "tools: \"${argc_tools:-}\""
        echo "files:"
        local f
        for f in "${argc_file[@]}"; do echo "  - $f"; done
        echo "---"
        echo
        echo "<one bounded question>"
    } >"$path"
    echo "$path"
}

# @cmd run a workorder, write <name>.result.json beside it
# @arg workorder![`_choice_workorder`] name or path
# @option -m --model                   model, defaults to the workorder's or $SKOGAI_MODEL
wo::run() {
    local path
    path="$(_workorder_path "$argc_workorder")"
    local fm
    fm="$(yq --front-matter=extract -o json '.' "$path")"
    [[ "$(jq -r '.type' <<<"$fm")" == workorder ]] || { echo "not a workorder: $path" >&2; return 2; }

    local files=() f
    while IFS= read -r f; do [[ -n "$f" ]] && files+=("$f"); done < <(jq -r '.files // [] | .[]' <<<"$fm")
    local schema model tools
    schema="$(jq -r '.schema // "answer"' <<<"$fm")"
    model="${argc_model:-$(jq -r --arg d "$SKOGAI_MODEL" '.model // $d' <<<"$fm")}"
    tools="$(jq -r '.tools // ""' <<<"$fm")"

    local result="${path%.md}.result.json"
    _compose "$(_body "$path")" "${files[@]}" | _agent "$schema" "$model" "$tools" "" >"$result"
    cat "$result"
}

# @cmd list workorders and whether they have a result
wo::ls() {
    local f
    for f in "$WORKORDERS"/*.md; do
        [[ -e "$f" ]] || continue
        if [[ -e "${f%.md}.result.json" ]]; then echo "done  $(basename "$f" .md)"; else echo "open  $(basename "$f" .md)"; fi
    done
}

# @cmd claude code plugins under plugins/
plugin() { :; }

# @cmd scaffold a plugin with one skill
# @arg name!                           kebab-case name
# @arg description!                    one line: what it is for
plugin::new() {
    local dir="$PLUGINS/$argc_name"
    [[ ! -e "$dir" ]] || { echo "exists: $dir" >&2; return 2; }
    mkdir -p "$dir/.claude-plugin" "$dir/skills/$argc_name"
    jq -n --arg n "$argc_name" --arg d "$argc_description" \
        '{name: $n, version: "0.1.0", description: $d, author: {name: "skogix"}}' >"$dir/.claude-plugin/plugin.json"
    printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' \
        "$argc_name" "$argc_description" "$argc_name" >"$dir/skills/$argc_name/SKILL.md"
    echo "$dir"
}

# @cmd validate plugins, all if no name is given
# @arg name*[`_choice_plugin`]
plugin::check() {
    local names=("${argc_name[@]}") n
    [[ ${#names[@]} -gt 0 ]] || mapfile -t names < <(_choice_plugin)
    for n in "${names[@]}"; do claude plugin validate "$PLUGINS/$n"; done
}

# @cmd run a plugin's evals
# @arg name![`_choice_plugin`]
plugin::eval() {
    claude plugin eval "$PLUGINS/$argc_name"
}

# @cmd hand a plugin to an agent for improvement, pure unless --apply
# @arg name![`_choice_plugin`]
# @arg request~                        what to change
# @flag --apply                        apply the patch to the tree
plugin::improve() {
    local files=()
    mapfile -t files < <(git ls-files --cached --others --exclude-standard "plugins/$argc_name")
    argc_file=("${files[@]}")
    improve
}

# @cmd static checks on the runner itself: argc parse, shellcheck, schemas, plugins
check() {
    argc --argc-export Argcfile.sh >/dev/null && echo "ok    argc parse"
    if command -v shellcheck >/dev/null; then
        shellcheck -x Argcfile.sh && echo "ok    shellcheck"
    else
        echo "skip  shellcheck: not installed"
    fi
    local s
    for s in "$SCHEMAS"/*.json; do jq -e . "$s" >/dev/null && echo "ok    schema $(basename "$s")"; done
    plugin::check
}

# prompt + files -> one message
_compose() {
    local prompt="$1"
    shift
    printf '<prompt>\n%s\n</prompt>\n' "$prompt"
    local f
    for f in "$@"; do
        [[ -f "$f" ]] || { echo "no such file: $f" >&2; return 2; }
        printf '\n<file path="%s">\n%s\n</file>\n' "$f" "$(cat "$f")"
    done
}

# message on stdin -> typed output on stdout, envelope logged
# _agent <schema> <model> <tools> <raw>
_agent() {
    local schema="$1" model="$2" tools="$3" raw="$4"
    local args=(-p --output-format json --model "$model" --tools "$tools" --permission-mode dontAsk)
    local a
    for a in "${argc_allow[@]}"; do args+=(--allowedTools "$a"); done
    for a in "${argc_plugin_dir[@]}"; do args+=(--plugin-dir "$a"); done
    [[ -n "$schema" ]] && args+=(--json-schema "$(jq -c . "$(_schema_path "$schema")")")

    mkdir -p "$LOGS"
    local log
    log="$LOGS/$(date +%Y%m%dT%H%M%S)-$$.json"
    claude "${args[@]}" >"$log"

    if [[ -n "$raw" ]]; then cat "$log"; fi
    if [[ "$(jq -r '.is_error' "$log")" == true ]]; then
        jq -r '.result // .subtype' "$log" >&2
        return 1
    fi
    [[ -n "$raw" ]] && return 0
    if [[ -n "$schema" ]]; then jq '.structured_output' "$log"; else jq -r '.result' "$log"; fi
}

# edit json + allowed files -> unified diff, refusing paths outside the list
_edit_to_patch() {
    local out="$1"
    shift
    local new path allowed f
    new="$(mktemp)"
    trap 'rm -f "$new"' RETURN
    while IFS= read -r path; do
        allowed=
        for f in "$@"; do [[ "$path" == "$f" ]] && allowed=1; done
        [[ -n "$allowed" ]] || { echo "refused: $path is not a handed-over file" >&2; return 2; }
        jq -j --arg p "$path" '.files[] | select(.path == $p) | .content' <<<"$out" >"$new"
        diff -u --label "a/$path" --label "b/$path" "$path" "$new" || true
    done < <(jq -r '.files[].path' <<<"$out")
}

_body() { awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "$1"; }

_schema_path() {
    if [[ -f "$1" ]]; then echo "$1"; else echo "$SCHEMAS/$1.json"; fi
}

_workorder_path() {
    if [[ -f "$1" ]]; then echo "$1"; else echo "$WORKORDERS/$1.md"; fi
}

_choice_schema() {
    local f
    for f in "$SCHEMAS"/*.json; do basename "$f" .json; done
}

_choice_workorder() {
    local f
    for f in "$WORKORDERS"/*.md; do [[ -e "$f" ]] && basename "$f" .md; done
}

_choice_plugin() {
    local d
    for d in "$PLUGINS"/*/.claude-plugin; do basename "$(dirname "$d")"; done
}

eval "$(argc --argc-eval "$0" "$@")"
