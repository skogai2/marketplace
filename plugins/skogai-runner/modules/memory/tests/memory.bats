#!/usr/bin/env bats

load "$SKOGAI_TEST_HELPER"

setup() {
    skogai_setup
    MEM="$LOCAL/memory"
    mkdir -p "$MEM"
    entry fresh "still good" "$(date -d '+5 days' +%F)"
    entry old "past it" 2020-01-01
    printf -- '---\nname: nested\ndescription: claude code format\nmetadata:\n  stale_after: 2020-02-01\n---\n' >"$MEM/nested.md"
    printf -- '---\nname: undated\ndescription: no stale_after\n---\n' >"$MEM/undated.md"
    printf '* [fresh](fresh.md) - still good\n' >"$MEM/MEMORY.md"
}

entry() { printf -- '---\nname: %s\ndescription: %s\nstale_after: %s\n---\n' "$1" "$2" "$3" >"$MEM/$1.md"; }

@test "memory ls: every entry, due ones marked" {
    run skogai memory ls
    assert_status 0
    assert_output_has "  $(date -d '+5 days' +%F) fresh"
    assert_output_has "! 2020-01-01 old"
    assert_output_has "! 2020-02-01 nested"
    assert_output_has "! none       undated"
    refute_output_has "MEMORY"
}

@test "memory stale: due entries, oldest first, exit 1" {
    run skogai memory stale
    assert_status 1
    [[ ${lines[0]} == old* && ${lines[1]} == nested* && ${lines[2]} == undated* ]]
    refute_output_has fresh
}

@test "memory stale: nothing due exits 0" {
    rm "$MEM"/{old,nested,undated}.md
    run skogai memory stale
    assert_status 0
    [[ -z $output ]]
}

@test "memory new: writes the template, stale after memory.stale-days" {
    skogai config set memory.stale-days 7
    run skogai memory new tabs "use tabs"
    assert_status 0
    run yq --front-matter=extract '.stale_after' "$MEM/tabs.md"
    assert_output_has "$(date -d '+7 days' +%F)"
}

@test "memory new: refuses an existing name and a bad one" {
    run skogai memory new fresh x
    assert_status 2
    run skogai memory new Bad_Name x
    assert_status 2
}

@test "memory index: missing lines are a plan, --apply appends them" {
    run skogai memory index
    assert_status 1
    assert_output_has "* [old](old.md) - past it"
    refute_output_has "(fresh.md)"
    skogai memory index --apply
    run skogai memory index
    assert_status 0
}

@test "memory index: a dead link is reported" {
    rm "$MEM"/{old,nested,undated}.md
    printf '* [gone](gone.md) - x\n' >>"$MEM/MEMORY.md"
    run skogai memory index
    assert_status 1
    assert_output_has "dead link: gone.md"
}

@test "memory: memory.dir moves where entries are read" {
    mkdir -p "$LOCAL/elsewhere"
    printf -- '---\nname: there\ndescription: moved\nstale_after: 2999-01-01\n---\n' >"$LOCAL/elsewhere/there.md"
    skogai config set memory.dir elsewhere
    run skogai memory ls
    assert_output_has there
    refute_output_has fresh
}

@test "memory index: links the file, whatever the entry's name" {
    rm "$MEM"/{old,nested,undated}.md
    printf -- '---\nname: Tabs Rule\ndescription: use tabs\nstale_after: 2999-01-01\n---\n' >"$MEM/tabs.md"
    run skogai memory index --apply
    assert_output_has "* [Tabs Rule](tabs.md) - use tabs"
    run skogai memory index
    assert_status 0
}

@test "memory index: a missing index is every entry, --apply writes it" {
    rm "$MEM/MEMORY.md"
    run skogai memory index
    assert_status 1
    assert_output_has "(fresh.md)"
    skogai memory index --apply 2>/dev/null
    assert_file "$MEM/MEMORY.md"
    run skogai memory index
    assert_status 0
}
