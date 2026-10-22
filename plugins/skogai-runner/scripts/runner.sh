#!/usr/bin/env bash
# @describe skogai command runner: typed io for handing work to agents
#
# every agent call is `prompt + files -> json matching a schema`.
# pure by default: only `--apply` changes existing files, scaffolds only create new ones.
# run it from anywhere: `argc --argc-run <plugin>/scripts/runner.sh <cmd>`.
# file arguments are relative to the current directory, state lives in
# `.skogai/` at the root of the current git repo.
# @meta require-tools jq,yq,git,claude
# @meta binname argc
# @env SKOGAI_MODEL=sonnet                         default model for agent calls
# @env ARGC_DOCS                                   argc docs handed to `improve`, default the plugin's docs/argc/

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.." && pwd)"
SCHEMAS="$PLUGIN_ROOT/schemas"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
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
# here with `diff -u`, so a bad hunk header can never break it.
# @arg request~                        what to change
# @option -f --file* <FILE>            files to hand over, default this script and the runner skill
# @option -m --model                   model, defaults to $SKOGAI_MODEL
# @flag      --apply                   apply the patch to the tree
# @alias i
improve() {
    local files=("${argc_file[@]}")
    [[ ${#files[@]} -gt 0 ]] || mapfile -t files < <(realpath --relative-to=. "$PLUGIN_ROOT/scripts/runner.sh" "$PLUGIN_ROOT/skills/argc/SKILL.md")
    local docs="${ARGC_DOCS:-$PLUGIN_ROOT/docs/argc}"
    docs="${docs/#\~/$HOME}"
    local ctx=()
    [[ -f "$docs/specification.md" ]] && ctx+=("$docs/specification.md")
    [[ -f "$docs/command-runner.md" ]] && ctx+=("$docs/command-runner.md")

    local prompt
    prompt="$(printf '%s\n\n%s\n%s\n' "${argc_request[*]}" \
        "return every file you change in full, paths exactly as handed over." \
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
        local path
        while IFS= read -r path; do
            # shellcheck disable=SC2094 # $path is a jq argument here, not a read
            jq -j --arg p "$path" '.files[] | select(.path == $p) | .content' <<<"$out" >"$path"
            echo "wrote $path" >&2
        done < <(jq -r '.files[].path' <<<"$out")
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
        for f in "${argc_file[@]}"; do echo "  - $(realpath -m --relative-to="$ROOT" "$f")"; done
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

    local result="${path%.md}.result.json" body
    body="$(_body "$path")"
    (cd "$ROOT" && _compose "$body" "${files[@]}") | _agent "$schema" "$model" "$tools" "" >"$result.tmp" ||
        { rm -f "$result.tmp"; return 1; }
    mv "$result.tmp" "$result"
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

# @cmd session journals (.skogai/journal.md): read them back, harvest them
journal() { :; }

# @cmd only the user's input, one json row per turn
# @arg file[?`_choice_journal`]         journal, default .skogai/journal.md
# @option --last <N>                   only the last N turns
# @flag   --md                         markdown instead of json rows
journal::prompts() {
    local file="${argc_file:-$ROOT/.skogai/journal.md}"
    local rows
    rows="$(_journal_slice "$file" "${argc_last:-0}" | awk '
        function flush() { if (turn != "") printf "%s\037%s\037%s\036", ts, turn, prompt; prompt = "" }
        /^## [0-9]{4}-/ { flush(); ts = $2 " " $3; turn = $NF; sec = ""; next }
        /^\*\*User\*\*$/ { sec = "user"; next }
        /^\*\*(Assistant|Actions)\*\*$/ { sec = ""; next }
        sec == "user" && /^>/ { sub(/^> ?/, ""); prompt = prompt (prompt == "" ? "" : "\n") $0 }
        END { flush() }' |
        jq -Rsc 'split("\u001e")[:-1][] | split("\u001f") | {ts: .[0], turn: .[1], prompt: .[2]}')"
    if [[ -n "${argc_md:-}" ]]; then
        jq -r '"## \(.ts) · turn \(.turn)\n\n\(.prompt)\n"' <<<"$rows"
    else
        printf '%s\n' "$rows"
    fi
}

# @cmd agents pick decisions, docs, todos and learnings out of a journal
#
# the journal is cut into chunks of --turns turns, each chunk goes to one
# worker with schema `harvest`. stdout is one json array of every item.
# @arg file[?`_choice_journal`]         journal, default .skogai/journal.md
# @option --last <N>                   only the last N turns
# @option --turns <N>                  turns per chunk, default 20
# @option -m --model                   model, defaults to $SKOGAI_MODEL
journal::harvest() {
    local file="${argc_file:-$ROOT/.skogai/journal.md}"
    local per="${argc_turns:-20}"
    local dir
    dir="$(mktemp -d)"
    trap 'rm -rf "$dir"' RETURN
    _journal_slice "$file" "${argc_last:-0}" |
        awk -v per="$per" -v dir="$dir" '/^## [0-9]{4}-/ && n++ % per == 0 { out = sprintf("%s/%03d.md", dir, n / per) } out { print > out }'

    local prompt
    prompt="$(cat <<'EOF'
the file is a slice of a session journal: turns between a user and an assistant.
pick out what is worth keeping after the session:
- decision: something settled, with why
- doc: how something works now, worth writing down
- todo: still open at the end of the slice
- learning: a gotcha or rule found the hard way
skip chatter, anything superseded later in the slice, and anything only true for that conversation.
turn is the id after "turn" in the heading where it was settled. an empty list is fine.
EOF
)"
    local chunk
    for chunk in "$dir"/*.md; do
        echo "harvest $(basename "$chunk") ($(grep -c '^## [0-9]' "$chunk") turns)" >&2
        _compose "$prompt" "$chunk" | _agent harvest "${argc_model:-$SKOGAI_MODEL}" "" "" >"${chunk%.md}.json"
    done
    jq -s '[.[].items[]]' "$dir"/*.json
}

# @cmd static checks on the runner itself: argc parse, shellcheck, schemas, plugin
check() {
    local self="$PLUGIN_ROOT/scripts/runner.sh"
    argc --argc-export "$self" >/dev/null && echo "ok    argc parse"
    if command -v shellcheck >/dev/null; then
        shellcheck -x "$self" && echo "ok    shellcheck"
    else
        echo "skip  shellcheck: not installed"
    fi
    local s
    for s in "$SCHEMAS"/*.json; do jq -e . "$s" >/dev/null && echo "ok    schema $(basename "$s")"; done
    claude plugin validate "$PLUGIN_ROOT"
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
    # claude exits 1 on agent errors; the envelope says why, so read it below
    claude "${args[@]}" >"$log" || true

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

# journal -> its last <n> turns, the whole journal if n is 0
_journal_slice() {
    local file="$1" n="$2"
    [[ -f "$file" ]] || { echo "no such journal: $file" >&2; return 2; }
    local total
    total="$(grep -c '^## [0-9]\{4\}-' "$file")"
    awk -v skip=$((n > 0 && total > n ? total - n : 0)) '/^## [0-9]{4}-/ { i++ } i > skip' "$file"
}

_choice_journal() {
    printf '%s\n' "$ROOT/.skogai/journal.md" "$HOME/skogai/.skogai/journal.md"
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

eval "$(argc --argc-eval "$0" "$@")"
