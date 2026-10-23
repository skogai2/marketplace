#!/usr/bin/env bats
# what every module is held to, run for each by `skogai module test`
# with SKOGAI_TEST_MODULE set. the spec is docs/module.md.

load "$SKOGAI_TEST_HELPER"

@test "contract: module check has no errors" {
    run skogai module check "$SKOGAI_TEST_MODULE"
    assert_status 0
}

@test "contract: --help exits 0" {
    [[ -n $(module_field .command) ]] || skip "no command"
    run skogai "$SKOGAI_TEST_MODULE" --help
    assert_status 0
}

@test "contract: the command refuses to run outside skogai" {
    [[ -n $(module_field .command) ]] || skip "no command"
    [[ $SKOGAI_TEST_MODULE != core ]] || skip "core is what runs modules"
    local cmd
    cmd="$(module_dir)/$(module_field .command)"
    run argc --argc-run "$cmd" "$(argc --argc-export "$cmd" | yq -p json '.subcommands[0].name')"
    [[ $status -ne 0 ]]
    assert_output_has "run me as"
}

@test "contract: config defaults resolve under its name" {
    local keys key
    # leaves, a list being one leaf; the assignment fails the test if yq does
    keys="$(yq --front-matter=extract '.config // {} | .. | select(tag == "!!seq" or (tag != "!!map" and (parent | tag) != "!!seq")) | path | .[1:] | join(".")' "$(module_dir)/module.md")"
    while IFS= read -r key; do
        [[ -n $key ]] || continue
        run skogai config get "$SKOGAI_TEST_MODULE.$key" --show-origin
        assert_status 0
        assert_output_has "module:$SKOGAI_TEST_MODULE"
    done <<<"$keys"
}

@test "contract: module env names it and its dir" {
    run skogai module env "$SKOGAI_TEST_MODULE"
    assert_status 0
    assert_output_has "export SKOGAI_MODULE=$SKOGAI_TEST_MODULE"
    assert_output_has "export SKOGAI_MODULE_DIR=$(module_dir)"
    assert_output_has "export SKOGAI_LOCAL_DIR=$LOCAL"
}

@test "contract: add is a plan, --apply installs, a second add is all same" {
    run skogai module add "$SKOGAI_TEST_MODULE"
    assert_status 1
    [[ ! -e $LOCAL/modules/$SKOGAI_TEST_MODULE ]]
    run skogai module add "$SKOGAI_TEST_MODULE" --apply
    assert_status 0
    assert_file "$LOCAL/modules/$SKOGAI_TEST_MODULE/module.md"
    run skogai module add "$SKOGAI_TEST_MODULE"
    assert_status 0
    refute_output_has "add "
    refute_output_has "keep "
}

@test "contract: the installed copy passes check and runs" {
    skogai module add "$SKOGAI_TEST_MODULE" --apply 2>/dev/null >/dev/null
    run skogai module show "$SKOGAI_TEST_MODULE"
    assert_output_has "local	$LOCAL/modules/$SKOGAI_TEST_MODULE"
    run skogai module check "$SKOGAI_TEST_MODULE"
    assert_status 0
    [[ -n $(yq --front-matter=extract '.command // ""' "$LOCAL/modules/$SKOGAI_TEST_MODULE/module.md") ]] || return 0
    run skogai "$SKOGAI_TEST_MODULE" --help
    assert_status 0
}
