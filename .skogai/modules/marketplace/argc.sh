#!/usr/bin/env bash
# @describe skogai-marketplace: scaffold, validate, eval and improve its plugins
#
# works on the repo this module is installed in.
# @meta require-tools jq,git,claude
# @meta binname skogai marketplace

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai marketplace\`}"
REPO="$(dirname "$SKOGAI_LOCAL_DIR")"
PLUGINS="$REPO/plugins"

# @cmd scaffold a plugin with one skill
# @arg name!                           kebab-case name
# @arg description!                    one line: what it is for
new() {
    local dir="$PLUGINS/$argc_name"
    [[ ! -e "$dir" ]] || { echo "exists: $dir" >&2; return 2; }
    mkdir -p "$dir/.claude-plugin" "$dir/skills/$argc_name"
    jq -n --arg n "$argc_name" --arg d "$argc_description" \
        '{name: $n, version: "0.1.0", description: $d, author: {name: "skogix"}}' >"$dir/.claude-plugin/plugin.json"
    printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' \
        "$argc_name" "$argc_description" "$argc_name" >"$dir/skills/$argc_name/SKILL.md"
    echo "$dir"
}

# @cmd validate plugins, all if no name is given, then check marketplace.json is generated
# @arg name*[`_choice_plugin`]
check() {
    local names=("${argc_name[@]}") n
    [[ ${#names[@]} -gt 0 ]] || mapfile -t names < <(_choice_plugin)
    for n in "${names[@]}"; do claude plugin validate "$PLUGINS/$n"; done
    "$REPO/scripts/generate-marketplace-json.sh" --check
}

# @cmd regenerate .claude-plugin/marketplace.json
json() {
    "$REPO/scripts/generate-marketplace-json.sh"
}

# @cmd run a plugin's evals
# @arg name![`_choice_plugin`]
evals() {
    claude plugin eval "$PLUGINS/$argc_name"
}

# @cmd hand a plugin to an agent for improvement, pure unless --apply
# @flag --apply                        apply the patch to the tree
# @arg name![`_choice_plugin`]
# @arg request~                        what to change; --apply goes before the name
improve() {
    local args=() f
    while IFS= read -r f; do args+=(-f "$f"); done < <(git -C "$REPO" ls-files --cached --others --exclude-standard "plugins/$argc_name")
    [[ -z "${argc_apply:-}" ]] || args+=(--apply)
    (cd "$REPO" && skogai runner improve "${args[@]}" "${argc_request[*]}")
}

_choice_plugin() {
    local d
    for d in "$PLUGINS"/*/.claude-plugin; do [[ -d $d ]] && basename "$(dirname "$d")"; done
}

eval "$(argc --argc-eval "$0" "$@")"
