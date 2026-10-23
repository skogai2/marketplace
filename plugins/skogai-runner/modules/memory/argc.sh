#!/usr/bin/env bash
# @describe memory: one fact per file, each with a stale_after; expired ones get decided on
# @meta require-tools yq
# @meta binname skogai memory

# shellcheck disable=SC2154 # argc_* are assigned by --argc-eval, SKOGAI_* by `skogai module env`
set -euo pipefail

: "${SKOGAI_MODULE_DIR:?run me as \`skogai memory\`}"
DIR="$SKOGAI_LOCAL_DIR/$SKOGAI_MEMORY_DIR"
INDEX="$DIR/$SKOGAI_MEMORY_INDEX"
# field separator of _entries: not whitespace, so an empty field survives `read`
FS=$'\x1f'

# @cmd every entry: stale_after, name, description; `!` marks one that is due (expired, or no stale_after)
ls() {
    local name stale desc
    while IFS="$FS" read -r name stale desc _; do
        printf '%s %-10s %-36s %s\n' "$([[ $stale == none || $stale < $(date +%F) ]] && echo '!' || echo ' ')" "$stale" "$name" "$desc"
    done < <(_entries)
}

# @cmd entries that are due, oldest first, as name<TAB>stale_after<TAB>description; exit 1 if there are any
stale() {
    local today out
    today="$(date +%F)"
    out="$(_entries | awk -F"$FS" -v OFS='\t' -v t="$today" '$2 == "none" || $2 < t { print $1, $2, $3 }' | sort -t$'\t' -k2)"
    [[ -n $out ]] || return 0
    printf '%s\n' "$out"
    return 1
}

# @cmd write a new entry from templates/entry.md; refuses an existing name
# @arg name!  lowercase, `-` inside a name
# @arg description!  one line, used for recall
# @option --days  days until stale, default memory.stale-days
new() {
    [[ $argc_name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "bad name: $argc_name" >&2; return 2; }
    local file="$DIR/$argc_name.md"
    [[ ! -e $file ]] || { echo "exists: $file" >&2; return 2; }
    mkdir -p "$DIR"
    NAME="$argc_name" DESC="$argc_description" CREATED="$(date +%F)" \
        STALE="$(date -d "+${argc_days:-$SKOGAI_MEMORY_STALEDAYS} days" +%F)" \
        awk '{ gsub(/\{\{name\}\}/, ENVIRON["NAME"]); gsub(/\{\{description\}\}/, ENVIRON["DESC"])
               gsub(/\{\{created\}\}/, ENVIRON["CREATED"]); gsub(/\{\{stale_after\}\}/, ENVIRON["STALE"]); print }' \
        "$SKOGAI_MODULE_DIR/templates/entry.md" >"$file"
    echo "wrote $file" >&2
    echo "not in the index yet: skogai memory index --apply" >&2
}

# @cmd index lines for entries missing from the index, and index links to missing files. pure unless --apply
#
# exit 1 when something is out of sync and --apply was not given.
# --apply appends the missing lines; dead links are only reported.
# @flag --apply  append the missing lines to the index
index() {
    local name stale desc file missing=() rc=0 link
    while IFS="$FS" read -r name stale desc file; do
        grep -qF "($file)" "$INDEX" 2>/dev/null || missing+=("* [$name]($file) - $desc")
    done < <(_entries)
    while IFS= read -r link; do
        [[ -f $DIR/$link ]] || { echo "dead link: $link" >&2; rc=1; }
    done < <(grep -o '([^)]*\.md)' "$INDEX" 2>/dev/null | tr -d '()')
    [[ ${#missing[@]} -gt 0 ]] || return "$rc"
    printf '%s\n' "${missing[@]}"
    if [[ ${argc_apply:-} == 1 ]]; then
        printf '%s\n' "${missing[@]}" >>"$INDEX"
        echo "appended ${#missing[@]} to $INDEX" >&2
        return "$rc"
    fi
    return 1
}

# "name FS stale_after FS description FS file" per entry, the index excluded;
# a missing stale_after is `none`, file is the entry's file name in the dir
_entries() {
    local f
    for f in "$DIR"/*.md; do
        [[ -f $f && $f != "$INDEX" ]] || continue
        FS="$FS" yq --front-matter=extract -r '[.name // "", .stale_after // .metadata.stale_after // "none", .description // ""] | join(strenv(FS))' "$f" | tr -d '\n'
        printf '%s%s\n' "$FS" "$(basename "$f")"
    done
}

eval "$(argc --argc-eval "$0" "$@")"
