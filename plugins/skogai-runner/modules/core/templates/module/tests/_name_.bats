#!/usr/bin/env bats
# run with `skogai module test {{name}}`: the contract first, then these.

load "$SKOGAI_TEST_HELPER"

@test "{{name}}: hello reads its greeting from config" {
    run skogai {{name}} hello skogix
    assert_status 0
    assert_output_has "hello, skogix"
    skogai config set {{name}}.greeting hej
    run skogai {{name}} hello skogix
    assert_output_has "hej, skogix"
}
