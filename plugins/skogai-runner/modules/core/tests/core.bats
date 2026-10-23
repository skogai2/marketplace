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

@test "module sandbox: run runs one command inside it, state kept between runs" {
    S="$BATS_TEST_TMPDIR/sb"
    skogai module sandbox "$S" >/dev/null 2>&1
    run env SKOGAI_RUNNER_MODEL=leak "$S/run" skogai config get runner.model --show-origin
    assert_output_has "module:runner"
    run "$S/run" pwd
    assert_output_has "$S/repo"
    "$S/run" skogai config set core.module.install global
    run "$S/run" skogai config get core.module.install --show-origin
    assert_output_has "local	global"
}

@test "config: unset removes a key from its layer, a missing one exits 1" {
    skogai config set some.key v
    skogai config set --global some.key g
    skogai config unset some.key
    run skogai config get some.key --show-origin
    assert_output_has "global	g"
    skogai config unset --global some.key
    run skogai config get some.key
    assert_status 1
    run skogai config unset some.key
    assert_status 1
}

@test "config: unset --module drops the override, the default is back" {
    skogai config set --module core core.module.install global
    skogai config unset --module core core.module.install
    run skogai config get core.module.install --show-origin
    assert_output_has "module:core	local"
}

@test "config: a null in module.local.md removes the default" {
    skogai config set --module core core.module.install null
    run skogai config get core.module.install
    assert_status 1
}

@test "config: list and env print every resolved key" {
    skogai config set some.key v
    run skogai config list --show-origin
    assert_status 0
    assert_output_has "local	some.key=v"
    assert_output_has "module:core	core.module.install=local"
    run skogai config env
    assert_output_has "export SKOGAI_SOME_KEY=v"
    assert_output_has "export SKOGAI_CORE_MODULE_INSTALL=local"
}

@test "config: a list default is one key, one item per line" {
    fixture tagged <<'MD'
---
type: module
name: tagged
description: has a list default
requires: [core]
config:
  tags: [a, b]
---
MD
    run skogai config get tagged.tags
    assert_status 0
    [[ $output == $'a\nb' ]]
    run skogai config list
    assert_output_has $'tagged.tags=a\ntagged.tags=b'
    run skogai module env tagged
    assert_output_has "export SKOGAI_TAGGED_TAGS=$'a\\nb'"
}

@test "config: --file is a layer with its .local.md after it, --scope mounts it" {
    printf -- '---\nsection:\n  key: fromfile\n---\nbody\n' >x.md
    run skogai config get section.key --file x.md --show-origin
    assert_output_has "file:x.md	fromfile"
    skogai config set --file x.md section.key fromlocal
    run skogai config get section.key --file x.md --show-origin
    assert_output_has "file:x.local.md	fromlocal"
    [[ $(tail -1 x.md) == body ]]
    run skogai config get s.section.key --file x.md --scope s
    assert_output_has fromlocal
    run skogai config set --file x.md --scope s other.key v
    assert_status 2
}

@test "config: files lists every layer and whether it is there" {
    skogai config set some.key v
    run skogai config files
    assert_status 0
    assert_output_has "local	$LOCAL/config	present"
    assert_output_has "global	$SKOGAI_CONFIG_DIR/config	missing"
    assert_output_has "system	$SKOGAI_SYSTEM_DIR/config	missing"
}

@test "local dir: the git root's .skogai from a subdir, pwd's outside git" {
    mkdir -p sub/deeper
    (cd sub/deeper && skogai config set some.key v)
    assert_file "$LOCAL/config"
    run bash -c 'cd sub && "$SKOGAI_BIN" module env memory'
    assert_output_has "export SKOGAI_LOCAL_DIR=$LOCAL"
    mkdir "$BATS_TEST_TMPDIR/nogit"
    cd "$BATS_TEST_TMPDIR/nogit"
    run skogai module env memory
    assert_output_has "export SKOGAI_LOCAL_DIR=$BATS_TEST_TMPDIR/nogit/.skogai"
}

@test "dispatch: an unknown command fails and names the known ones" {
    run skogai nosuch
    [[ $status -ne 0 ]]
    assert_output_has "subcommands: config, module"
}

@test "module show and command: where it is, its manifest, its argc script" {
    run skogai module show memory
    assert_status 0
    [[ ${lines[0]} == source$'\t'*/memory ]]
    assert_output_has "name: memory"
    run skogai module command memory
    [[ $output == */memory/argc.sh ]]
    fixture bare <<<$'---\ntype: module\nname: bare\ndescription: no command\nrequires: [core]\n---'
    run skogai module command bare
    assert_status 1
    run skogai module show nosuch
    assert_status 1
}

@test "module diff: an unchanged copy is exit 0, one without a source is exit 2" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module diff core
    assert_status 0
    [[ -z $output ]]
    fixture gone <<<$'---\ntype: module\nname: gone\ndescription: x\nrequires: [core]\n---'
    skogai module add "$FIX/gone" --apply >/dev/null 2>&1
    rm -rf "$FIX/gone"
    run skogai module diff gone
    assert_status 2
}

@test "module add: the installed copy itself is already installed, exit 0" {
    skogai module add core --apply >/dev/null 2>&1
    run skogai module add "$LOCAL/modules/core"
    assert_status 0
    assert_output_has "already installed"
}

@test "module add: only module.md, the command and files: are copied" {
    fixture shipped <<<$'---\ntype: module\nname: shipped\ndescription: x\nrequires: [core]\nfiles: [templates/]\n---'
    mkdir -p "$FIX/shipped/templates/sub" "$FIX/shipped/tests"
    touch "$FIX/shipped/templates/sub/t.md" "$FIX/shipped/tests/shipped.bats" "$FIX/shipped/notes.md"
    skogai module add shipped --apply >/dev/null 2>&1
    assert_file "$LOCAL/modules/shipped/templates/sub/t.md"
    [[ ! -e $LOCAL/modules/shipped/tests && ! -e $LOCAL/modules/shipped/notes.md ]]
}

@test "module check: the rest of the spec problems" {
    fixture worse <<'MD'
---
type: thing
name: worse
description: |
  two
  lines
command: argc.sh
files: [gone.txt]
config: [1]
requires: [core]
---
MD
    printf '#!/usr/bin/env bash\n# @cmd\n# @option --x[`\nfoo() { :; }\n' >"$FIX/worse/argc.sh"
    fixture help <<<$'---\ntype: module\nname: help\ndescription: x\nrequires: [core]\n---'
    fixture plain <<<'# no frontmatter'
    run skogai module check "$FIX/worse" "$FIX/help" "$FIX/plain"
    assert_status 1
    assert_output_has "worse	error	type is not module"
    assert_output_has "worse	error	description is not one line"
    assert_output_has "worse	error	command argc.sh does not parse with argc"
    assert_output_has "worse	error	file gone.txt is missing"
    assert_output_has "worse	error	config is not a map"
    assert_output_has "worse	warn	no tests/*.bats"
    assert_output_has "help	error	name is reserved"
    assert_output_has "plain	error	module.md has no frontmatter map"
}

@test "module test: a failing test fails the run, --filter picks tests, an unknown module fails" {
    fixture flaky <<<$'---\ntype: module\nname: flaky\ndescription: one test fails\nrequires: [core]\n---'
    mkdir "$FIX/flaky/tests"
    cat >"$FIX/flaky/tests/flaky.bats" <<'BATS'
load "$SKOGAI_TEST_HELPER"
@test "flaky: passes" { true; }
@test "flaky: fails" { false; }
BATS
    run skogai module test flaky
    assert_status 1
    assert_output_has "not ok"
    assert_output_has "flaky: fails"
    run skogai module test flaky --filter "^flaky: passes"
    assert_status 0
    refute_output_has "contract:"
    run skogai module test nosuch
    assert_status 1
    assert_output_has "invalid value `nosuch`"
}

@test "hook: SessionStart builds into the global dir, only env lines into CLAUDE_ENV_FILE" {
    local root cmd
    root="$(dirname "$(dirname "$SKOGAI_BIN")")"
    cmd="$(jq -r '.hooks.SessionStart[0].hooks[0].command' "$root/hooks/hooks.json")"
    CLAUDE_PLUGIN_ROOT="$root" bash -c "$cmd"
    [[ ! -e $SKOGAI_CONFIG_DIR/tmp/skogai ]]
    CLAUDE_PLUGIN_ROOT="$root" CLAUDE_ENV_FILE="$BATS_TEST_TMPDIR/env" bash -c "$cmd"
    assert_file "$SKOGAI_CONFIG_DIR/tmp/skogai/bin/skogai"
    run cat "$BATS_TEST_TMPDIR/env"
    assert_output_has "export PATH=$SKOGAI_CONFIG_DIR/tmp/skogai/bin:"
    refute_output_has "source "
    [[ $(grep -cv '^export ' "$BATS_TEST_TMPDIR/env") == 0 ]]
}
