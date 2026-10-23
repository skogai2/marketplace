#!/usr/bin/env bats
# what every module that requires type is held to, run by `skogai module test`
# with SKOGAI_TEST_MODULE set: its schemas compile, each has a glob, and its
# instances in a fresh repo check.

load "$SKOGAI_TEST_HELPER"

schemas() { compgen -G "$(module_dir)/schema/*.json" || true; }

@test "type contract: every schema/*.json compiles" {
    local s
    while IFS= read -r s; do
        [[ -n $s ]] || continue
        run ajv compile --spec=draft2020 --strict=true -s "$s"
        assert_status 0
    done < <(schemas)
}

@test "type contract: every schema has a glob in config" {
    local s
    while IFS= read -r s; do
        [[ -n $s ]] || continue
        run skogai config get "$SKOGAI_TEST_MODULE.schema.$(basename "$s" .json)"
        assert_status 0
        [[ -n $output ]]
    done < <(schemas)
}

@test "type contract: type check passes in a fresh repo" {
    run skogai type check "$SKOGAI_TEST_MODULE"
    assert_status 0
}
