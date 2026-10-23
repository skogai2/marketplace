#!/usr/bin/env bats
# thing is a fixture module that requires type: schema/item.json, instances
# in <thing.dir>/*.md.

load "$SKOGAI_TEST_HELPER"

setup() {
    skogai_setup
    local m="$BATS_TEST_TMPDIR/mods/thing"
    mkdir -p "$m/schema"
    printf -- '---\ntype: module\nname: thing\ndescription: a fixture\nrequires: [core, type]\nfiles:\n  - schema/\nconfig:\n  dir: things\n  schema:\n    item: <dir>/*.md\n---\n' >"$m/module.md"
    printf '{"type": "object", "required": ["name"], "properties": {"name": {"type": "string"}}}\n' >"$m/schema/item.json"
    export SKOGAI_MODULE_PATH="$BATS_TEST_TMPDIR/mods:$SKOGAI_MODULE_PATH"
    THINGS="$LOCAL/things"
    mkdir -p "$THINGS"
    item good 'name: good'
}

item() { printf -- '---\n%s\n---\nbody\n' "$2" >"$THINGS/$1.md"; }

@test "type check: valid instances pass" {
    run skogai type check thing
    assert_status 0
    [[ -z $output ]]
}

@test "type check: an invalid instance fails with a line naming it" {
    item bad 'name: 1'
    item none 'other: x'
    run skogai type check thing
    assert_status 1
    assert_output_has "thing	$THINGS/bad.md	/name must be string"
    assert_output_has "thing	$THINGS/none.md	must have required property 'name'"
    refute_output_has good.md
}

@test "type check: one line per file, its problems joined" {
    printf '{"type": "object", "required": ["name", "kind"], "properties": {"name": {"type": "string"}, "kind": {"type": "string"}}}\n' >"$(module_dir thing)/schema/item.json"
    item bad 'other: x'
    run skogai type check thing
    assert_status 1
    [[ ${#lines[@]} -eq 2 ]]
    assert_output_has "thing	$THINGS/bad.md	must have required property 'name'; must have required property 'kind'"
}

@test "type check: a glob is bash extglob, <key> filled inside it" {
    skogai config set thing.schema.item '<dir>/!(skip).md'
    item skip 'name: 1'
    run skogai type check thing
    assert_status 0
    run skogai type ls thing
    assert_output_has "thing	item	things/!(skip).md	1"
}

@test "type check --schema: files against <module>.<x>, the same lines" {
    printf -- '---\nname: x\n---\n' >ok.md
    printf -- '---\nname: 1\n---\n' >bad.md
    run skogai type check --schema thing.item ok.md
    assert_status 0
    run skogai type check --schema thing.item ok.md bad.md
    assert_status 1
    assert_output_has "thing	bad.md	/name must be string"
    refute_output_has ok.md
    run skogai type check --schema thing.nope ok.md
    assert_status 2
}

@test "type check: frontmatter that does not parse is a problem" {
    printf -- '---\nname: [\n---\n' >"$THINGS/broken.md"
    run skogai type check thing
    assert_status 1
    assert_output_has "thing	$THINGS/broken.md	frontmatter:"
}

@test "type check: a schema with no glob is an error" {
    printf '{"type": "object"}\n' >"$(module_dir thing)/schema/other.json"
    run skogai type check thing
    assert_status 1
    assert_output_has "no glob: config thing.schema.other"
    run skogai type ls thing
    assert_status 1
}

@test "type check: a schema that does not compile is a problem" {
    printf '{"type": "object", "nope": 1}\n' >"$(module_dir thing)/schema/item.json"
    run skogai type check thing
    assert_status 1
    assert_output_has "thing	$THINGS/good.md	"
    assert_output_has "unknown keyword"
}

@test "type: <key> in a glob is the module's own config" {
    skogai config set thing.dir elsewhere
    mkdir -p "$LOCAL/elsewhere"
    printf -- '---\nname: 1\n---\n' >"$LOCAL/elsewhere/moved.md"
    run skogai type ls thing
    assert_status 0
    assert_output_has "thing	item	elsewhere/*.md	1"
    run skogai type check thing
    assert_status 1
    assert_output_has "$LOCAL/elsewhere/moved.md"
    refute_output_has good.md
}

@test "type: a <key> with no config is an error" {
    skogai config set thing.schema.item '<nowhere>/*.md'
    run skogai type check thing
    assert_status 1
    assert_output_has "no config thing.nowhere for <nowhere>"
}

@test "type: without a module, every module that requires type" {
    item bad 'name: 1'
    run skogai type ls
    assert_output_has "thing	item	things/*.md	2"
    run skogai type check
    assert_status 1
    assert_output_has "$THINGS/bad.md"
}
