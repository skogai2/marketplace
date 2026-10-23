#!/usr/bin/env bats
# core's own behaviour: config layers and the module commands.

load "$SKOGAI_TEST_HELPER"

# a module source dir of our own, first on the path
fixture() {
    FIX="$BATS_TEST_TMPDIR/sources"
    export SKOGAI_MODULE_PATH="$FIX:$SKOGAI_MODULE_PATH"
    mkdir -p "$FIX/$1"
    cat >"$FIX/$1/module.md"
}

@test "config: a module default resolves with its origin" {
    run skogai config get core.module.install --show-origin
    assert_status 0
    assert_output_has "module:core	local"
}

@test "config: fold order module < system < global < local < module.local.md < env" {
    mkdir -p "$SKOGAI_SYSTEM_DIR"
    git config -f "$SKOGAI_SYSTEM_DIR/config" core.module.install system
    run skogai config get core.module.install --show-origin
    assert_output_has "system	system"
    skogai config set --global core.module.install global
    run skogai config get core.module.install --show-origin
    assert_output_has "global	global"
    skogai config set core.module.install local
    run skogai config get core.module.install --show-origin
    assert_output_has "local	local"
    skogai module add core --apply >/dev/null 2>&1
    skogai config set --module core core.module.install fromlocalmd
    run skogai config get core.module.install --show-origin
    assert_output_has "module:core.local	fromlocalmd"
    SKOGAI_CORE_MODULE_INSTALL=env run skogai config get core.module.install --show-origin
    assert_output_has "env:SKOGAI_CORE_MODULE_INSTALL	env"
}

@test "config: get of an unset key exits 1" {
    run skogai config get no.such.key
    assert_status 1
}

@test "config: set --module writes module.local.md under config:" {
    skogai module add core --apply >/dev/null 2>&1
    skogai config set --module core core.module.install global
    run yq --front-matter=extract .config.module.install "$LOCAL/modules/core/module.local.md"
    assert_output_has global
}

@test "config: set --module on a source module writes the local install dir" {
    skogai config set --module core core.module.install global
    run skogai config get core.module.install --show-origin
    assert_output_has "module:core.local	global"
    run yq --front-matter=extract .config.module.install "$LOCAL/modules/core/module.local.md"
    assert_output_has global
}

@test "config: set --module refuses a key outside the module" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai config set --module core other.key x
    assert_status 2
}

@test "module ls: a source module is listed as source" {
    run skogai module ls
    assert_status 0
    assert_output_has "core         source"
}

@test "module add: a changed installed file is kept, diff shows it" {
    skogai module add core --apply >/dev/null 2>&1
    echo extra >>"$LOCAL/modules/core/module.md"
    run skogai module add core --apply
    assert_status 0
    assert_output_has "keep  module.md"
    [[ $(tail -1 "$LOCAL/modules/core/module.md") == extra ]]
    run skogai module diff core
    assert_status 1
    assert_output_has "+extra"
}

@test "module add: --to global installs into the global dir" {
    run skogai module add core --to global --apply
    assert_status 0
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "module add: core.module.install picks the default target" {
    skogai config set core.module.install global
    skogai module add core --apply >/dev/null 2>&1
    assert_file "$SKOGAI_CONFIG_DIR/modules/core/module.md"
}

@test "module add: an unknown source is a usage error" {
    run skogai module add nosuchmodule
    assert_status 2
}

@test "module new: scaffolds a module that passes its own tests" {
    run skogai module new greet "says hello"
    assert_status 0
    assert_file "$LOCAL/modules/greet/tests/greet.bats"
    run skogai module check greet
    assert_status 0
    run skogai greet hello skogix
    assert_output_has "hello, skogix"
    skogai config set greet.greeting hej
    run skogai greet hello skogix
    assert_output_has "hej, skogix"
}

@test "module new: refuses reserved, bad and existing names" {
    run skogai module new config x
    assert_status 2
    run skogai module new Bad x
    assert_status 2
    skogai module new greet x 2>/dev/null
    run skogai module new greet x
    assert_status 2
}

@test "module check: reports every spec problem" {
    fixture bad <<'MD'
---
type: module
name: Bad
description: x
command: nope.sh
files: a
requires: [ghost]
tools: [nosuchtool]
foo: 1
---
MD
    run skogai module check "$FIX/bad"
    assert_status 1
    assert_output_has "name is not the directory name"
    assert_output_has "command nope.sh is missing"
    assert_output_has "files is not a list"
    assert_output_has "does not require core"
    assert_output_has "requires ghost, not found"
    assert_output_has "warn	tool nosuchtool not on PATH"
    assert_output_has "warn	unknown field foo"
}

@test "module: a local module shadows its source" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module ls
    assert_output_has "core         local"
}

@test "dispatch: a module command gets its env" {
    fixture envy <<'MD'
---
type: module
name: envy
description: prints its env
command: argc.sh
requires: [core]
config:
  some-key: v
---
MD
    cat >"$FIX/envy/argc.sh" <<'SH'
#!/usr/bin/env bash
# @cmd
show() { env | grep '^SKOGAI_' | grep -v 'PATH\|BIN' | sort; }
eval "$(argc --argc-eval "$0" "$@")"
SH
    run skogai envy show
    assert_status 0
    assert_output_has "SKOGAI_MODULE=envy"
    assert_output_has "SKOGAI_MODULE_DIR=$FIX/envy"
    assert_output_has "SKOGAI_LOCAL_DIR=$LOCAL"
    assert_output_has "SKOGAI_ENVY_SOMEKEY=v"
}

@test "module build: the built skogai lists, runs and completes every module" {
    run skogai module build --shell bash
    assert_status 0
    B="$LOCAL/tmp/skogai"
    assert_output_has "export PATH=$B/bin:"
    assert_file "$B/bin/skogai"
    assert_file "$B/completions/skogai.sh"
    assert_file "$B/completions/skogai.fish"
    assert_file "$B/man/man1/skogai.1"
    assert_file "$B/man/man1/skogai-module-build.1"
    run "$B/bin/skogai" --help
    assert_output_has "  config "
    assert_output_has "  memory "
    run "$B/bin/skogai" config get core.module.install
    assert_output_has local
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai memory ""
    assert_output_has stale
    run env ARGC_COMPLETIONS_PATH="$B/completions" argc --argc-compgen generic "" skogai config get ""
    assert_output_has core.module.install
}

@test "module build: a module added after the build still runs" {
    skogai module build >/dev/null 2>&1
    skogai module new late "came later" >/dev/null 2>&1
    run "$LOCAL/tmp/skogai/bin/skogai" late hello you
    assert_status 0
    assert_output_has "hello, you"
}

@test "module build: --shell fish prints fish lines, --to global builds there" {
    run skogai module build --to global --shell fish
    assert_status 0
    assert_output_has "fish_add_path --prepend $SKOGAI_CONFIG_DIR/tmp/skogai/bin"
    assert_file "$SKOGAI_CONFIG_DIR/tmp/skogai/bin/skogai"
}

@test "module sandbox: every module installed, skogai built, env lines into it" {
    fixture lonely <<<$'---\ntype: module\nname: lonely\ndescription: only found, no command\nrequires: [core]\n---'
    skogai module add "$FIX/lonely" --to global --apply >/dev/null 2>&1
    rm -rf "$FIX/lonely"
    S="$BATS_TEST_TMPDIR/sb"
    run --separate-stderr skogai module sandbox "$S" --shell bash
    assert_status 0
    assert_output_has "export SKOGAI_CONFIG_DIR=$S/global"
    assert_output_has "export SKOGAI_LOCAL_DIR=$S/repo/.skogai"
    assert_output_has "export PATH=$S/repo/.skogai/tmp/skogai/bin:"
    assert_output_has "cd $S/repo"
    assert_file "$S/repo/.skogai/modules/memory/module.md"
    assert_file "$S/repo/.skogai/modules/lonely/module.md"
    eval "$output"
    run skogai module ls
    assert_output_has "memory       local"
    refute_output_has source
}

@test "module sandbox: replaces an earlier sandbox, refuses any other dir" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai module sandbox "$S" >/dev/null 2>&1
    touch "$S/repo/leftover"
    run skogai module sandbox "$S"
    assert_status 0
    [[ ! -e $S/repo/leftover ]]
    mkdir -p "$BATS_TEST_TMPDIR/other"
    run skogai module sandbox "$BATS_TEST_TMPDIR/other"
    assert_status 2
}
