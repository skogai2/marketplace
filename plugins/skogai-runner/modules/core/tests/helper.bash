# the base every module's tests stand on: `load "$SKOGAI_TEST_HELPER"` at the
# top of a .bats file. each test gets an empty git repo as its cwd and its own
# system, global and local layers, so nothing outside BATS_TEST_TMPDIR is
# read or written. a file that defines its own setup() calls skogai_setup.
#
# set by `skogai module test`: SKOGAI_BIN, SKOGAI_MODULE_PATH,
# SKOGAI_TEST_MODULE (the module under test), SKOGAI_TEST_HELPER (this file).

skogai_setup() {
    local v
    # run --separate-stderr
    bats_require_minimum_version 1.5.0
    # config from the caller's env would shadow every layer
    for v in $(compgen -e SKOGAI_); do
        case "$v" in SKOGAI_BIN | SKOGAI_MODULE_PATH | SKOGAI_TEST_*) ;; *) unset "$v" ;; esac
    done
    export SKOGAI_SYSTEM_DIR="$BATS_TEST_TMPDIR/system"
    export SKOGAI_CONFIG_DIR="$BATS_TEST_TMPDIR/global"
    REPO="$BATS_TEST_TMPDIR/repo"
    LOCAL="$REPO/.skogai"
    mkdir -p "$REPO"
    cd "$REPO" || return 1
    git init -q
}

setup() { skogai_setup; }

# modules call `skogai <other>`, so it is on PATH as well
PATH="$(dirname "$SKOGAI_BIN"):$PATH"
skogai() { "$SKOGAI_BIN" "$@"; }

# the source dir of the module under test, or of $1
module_dir() { skogai module show "${1:-$SKOGAI_TEST_MODULE}" | awk -F"\t" "NR == 1 { print \$2 }"; }

# a manifest field of the module under test, empty if missing
module_field() { yq --front-matter=extract "$1 // \"\"" "$(module_dir)/module.md"; }

assert_status() {
    [[ $status -eq $1 ]] || { printf 'expected exit %s, got %s\n%s\n' "$1" "$status" "$output" >&2; return 1; }
}

assert_output_has() {
    [[ $output == *"$1"* ]] || { printf 'output lacks: %s\n---\n%s\n' "$1" "$output" >&2; return 1; }
}

refute_output_has() {
    [[ $output != *"$1"* ]] || { printf 'output has: %s\n---\n%s\n' "$1" "$output" >&2; return 1; }
}

assert_file() { [[ -f $1 ]] || { echo "no file: $1" >&2; return 1; }; }
