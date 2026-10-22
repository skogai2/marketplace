#!/usr/bin/env bash
# @describe skogai-marketplace runner: the skogai-runner core plus recipes for plugins/
#
# send, improve, wo and journal forward to plugins/skogai-runner/scripts/runner.sh,
# run from the directory argc was called in. `argc <cmd> --help` shows the core's help.
# @meta require-tools jq,git,claude
# @meta dotenv
# @meta binname argc
# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval
set -euo pipefail

PLUGINS="$PWD/plugins"
CORE="$PLUGINS/skogai-runner/scripts/runner.sh"

# @cmd send a prompt and files to an agent, print its typed output
# @arg args~
# @alias s
send() { _core send "${argc_args[@]}"; }

# @cmd ask an agent to edit files, print the patch. pure unless --apply
# @arg args~
# @alias i
improve() { _core improve "${argc_args[@]}"; }

# @cmd workorders: new, run, ls
# @arg args~
wo() { _core wo "${argc_args[@]}"; }

# @cmd session journals: prompts, harvest
# @arg args~
journal() { _core journal "${argc_args[@]}"; }

# @cmd the runner's own checks, then every plugin
check() {
    _core check
    plugin::check
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
    local args=("${argc_request[*]}") f
    while IFS= read -r f; do args+=(-f "$f"); done < <(git ls-files --cached --others --exclude-standard "plugins/$argc_name")
    [[ -z "${argc_apply:-}" ]] || args+=(--apply)
    argc --argc-run "$CORE" improve "${args[@]}"
}

# core recipe, run from the caller's directory
_core() {
    (cd "${ARGC_PWD:-$PWD}" && argc --argc-run "$CORE" "$@")
}

_choice_plugin() {
    local d
    for d in "$PLUGINS"/*/.claude-plugin; do basename "$(dirname "$d")"; done
}

eval "$(argc --argc-eval "$0" "$@")"
