#!/usr/bin/env bats

load "$SKOGAI_TEST_HELPER"

@test "new: scaffolds a plugin with a manifest and one skill" {
    run skogai marketplace new demo "a demo plugin"
    assert_status 0
    [[ $(jq -r .name plugins/demo/.claude-plugin/plugin.json) == demo ]]
    assert_file plugins/demo/skills/demo/SKILL.md
}

@test "new: refuses an existing plugin" {
    skogai marketplace new demo x >/dev/null
    run skogai marketplace new demo x
    assert_status 2
}
