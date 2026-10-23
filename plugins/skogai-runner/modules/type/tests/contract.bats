#!/usr/bin/env bats
# what every module that requires type is held to, run by `skogai module test`
# with SKOGAI_TEST_MODULE set: each schema/<x>.json compiles, has a glob, and
# ships tests/fixtures/<x>/valid/* that pass and tests/fixtures/<x>/invalid/*
# that fail, checked the way `skogai type check` checks instances.

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

@test "type contract: every schema has valid and invalid fixtures" {
    local s x d
    while IFS= read -r s; do
        [[ -n $s ]] || continue
        x="$(basename "$s" .json)"
        for d in valid invalid; do
            compgen -G "$(module_dir)/tests/fixtures/$x/$d/*" >/dev/null ||
                { echo "no fixtures: tests/fixtures/$x/$d/*" >&2; return 1; }
        done
    done < <(schemas)
}

@test "type contract: valid fixtures pass, each invalid one fails" {
    local s x f
    while IFS= read -r s; do
        [[ -n $s ]] || continue
        x="$(basename "$s" .json)"
        mapfile -t valid < <(compgen -G "$(module_dir)/tests/fixtures/$x/valid/*")
        run skogai type check --schema "$SKOGAI_TEST_MODULE.$x" "${valid[@]}"
        assert_status 0
        while IFS= read -r f; do
            run skogai type check --schema "$SKOGAI_TEST_MODULE.$x" "$f"
            assert_status 1
            assert_output_has "$SKOGAI_TEST_MODULE	$f	"
        done < <(compgen -G "$(module_dir)/tests/fixtures/$x/invalid/*")
    done < <(schemas)
}

@test "type contract: type check passes in a fresh repo" {
    run skogai type check "$SKOGAI_TEST_MODULE"
    assert_status 0
}
