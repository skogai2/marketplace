#!/usr/bin/env bats
# claude is a stub: it records its args, stdin and where it ran, counts its
# calls, and prints $STUB_ENVELOPE.

load "$SKOGAI_TEST_HELPER"

setup() {
    skogai_setup
    mkdir -p "$BATS_TEST_TMPDIR/stub"
    cat >"$BATS_TEST_TMPDIR/stub/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/claude.args"
echo call >>"$BATS_TEST_TMPDIR/claude.calls"
cat >"$BATS_TEST_TMPDIR/claude.stdin"
{ pwd; echo "config=${SKOGAI_CONFIG_DIR:-}"; } >"$BATS_TEST_TMPDIR/claude.where"
printf '%s' "$STUB_ENVELOPE"
SH
    chmod +x "$BATS_TEST_TMPDIR/stub/claude"
    PATH="$BATS_TEST_TMPDIR/stub:$PATH"
    ok '{"answer": "42"}'
}

# the envelope claude -p --output-format json would print, with structured output $1
ok() { export STUB_ENVELOPE="{\"is_error\": false, \"result\": \"done\", \"structured_output\": $1}"; }

# the line after $1 in claude's args, e.g. the value of an option
arg_after() { grep -A1 -x -- "$1" "$BATS_TEST_TMPDIR/claude.args" | sed -n 2p; }

# a bare `! cmd` never fails a bats test; a function returning it does
refute_arg() { ! grep -qx -- "$1" "$BATS_TEST_TMPDIR/claude.args"; }

calls() { wc -l <"$BATS_TEST_TMPDIR/claude.calls"; }

# a journal of two turns, as the journal hook writes it
journal_fixture() {
    mkdir -p "$LOCAL"
    cat >"$LOCAL/journal.md" <<'MD'
## 2026-10-22 10:00 · turn a1

**User**

> first question

**Assistant**

an answer

## 2026-10-22 10:05 · turn a2

**User**

> second
> two lines
MD
}

@test "send: files are inlined, the schema is passed, stdout is the object" {
    echo "hello" >in.txt
    run skogai runner send -p "what?" -f in.txt -s answer
    assert_status 0
    [[ $(jq -r .answer <<<"$output") == 42 ]]
    grep -q '<file path="in.txt">' "$BATS_TEST_TMPDIR/claude.stdin"
    grep -q '^--json-schema$' "$BATS_TEST_TMPDIR/claude.args"
    grep -qx sonnet "$BATS_TEST_TMPDIR/claude.args"
}

@test "send: runner.model picks the model" {
    skogai config set runner.model haiku
    echo q | skogai runner send -s answer
    grep -qx haiku "$BATS_TEST_TMPDIR/claude.args"
}

@test "send: an agent error exits 1 and logs the envelope" {
    export STUB_ENVELOPE='{"is_error": true, "result": "boom"}'
    run skogai runner send -p q -s answer
    assert_status 1
    assert_output_has boom
    compgen -G "$LOCAL/logs/runner/*.json" >/dev/null
}

@test "improve: prints the patch and exits 1, --apply writes" {
    printf 'old\n' >f.txt
    ok '{"summary": "s", "files": [{"path": "f.txt", "content": "new\n"}]}'
    run skogai runner improve -f f.txt "change it"
    assert_status 1
    assert_output_has "+new"
    [[ $(cat f.txt) == old ]]
    run skogai runner improve -f f.txt --apply "change it"
    assert_status 0
    [[ $(cat f.txt) == new ]]
}

@test "improve: a path not handed over is refused" {
    printf 'old\n' >f.txt
    ok '{"summary": "s", "files": [{"path": "other.txt", "content": "x"}]}'
    run skogai runner improve -f f.txt "change it"
    assert_status 2
    assert_output_has "refused: other.txt"
}

@test "wo: new, ls open, run writes the result, ls done" {
    echo input >in.md
    run skogai runner wo new ask -s answer -f in.md
    assert_status 0
    assert_file "$LOCAL/workorders/ask.md"
    run skogai runner wo ls
    assert_output_has "open  ask"
    run skogai runner wo run ask
    assert_status 0
    [[ $(jq -r .answer "$LOCAL/workorders/ask.result.json") == 42 ]]
    grep -q '<file path="in.md">' "$BATS_TEST_TMPDIR/claude.stdin"
    run skogai runner wo ls
    assert_output_has "done  ask"
}

@test "wo new: refuses an existing workorder" {
    skogai runner wo new ask >/dev/null
    run skogai runner wo new ask
    assert_status 2
}

@test "journal prompts: only the user's input, per turn" {
    journal_fixture
    run skogai runner journal prompts
    assert_status 0
    [[ $(jq -s length <<<"$output") == 2 ]]
    [[ $(jq -rs '.[1].prompt' <<<"$output") == $'second\ntwo lines' ]]
    refute_output_has "an answer"
    run skogai runner journal prompts --last 1
    [[ $(jq -s length <<<"$output") == 1 ]]
}

@test "wo run: the worker runs where it is called, with the caller's config" {
    skogai runner wo new ask -s answer >/dev/null
    skogai runner wo run ask >/dev/null
    grep -qx "$REPO" "$BATS_TEST_TMPDIR/claude.where"
}

@test "wo run: --sandbox runs the worker in a sandbox with every module installed" {
    echo input >in.md
    skogai runner wo new ask -s answer -f in.md >/dev/null
    run --separate-stderr skogai runner wo run ask --sandbox
    assert_status 0
    S="$LOCAL/tmp/sandbox/ask"
    [[ $stderr == *"sandbox: $S"* ]]
    grep -qx "$S/repo" "$BATS_TEST_TMPDIR/claude.where"
    grep -qx "config=$S/global" "$BATS_TEST_TMPDIR/claude.where"
    grep -q '<file path="in.md">' "$BATS_TEST_TMPDIR/claude.stdin"
    assert_file "$S/repo/.skogai/modules/runner/module.md"
    [[ $(jq -r .answer "$LOCAL/workorders/ask.result.json") == 42 ]]
}

@test "wo new --sandbox: the workorder runs sandboxed without the flag" {
    skogai runner wo new ask -s answer --sandbox >/dev/null
    grep -qx "sandbox: true" "$LOCAL/workorders/ask.md"
    skogai runner wo run ask 2>/dev/null
    grep -qx "$LOCAL/tmp/sandbox/ask/repo" "$BATS_TEST_TMPDIR/claude.where"
}

@test "wo: allow patterns reach the worker" {
    skogai runner wo new ask -s answer -t Bash -a 'Bash(pwd)' -a 'Bash(git log *)' >/dev/null
    skogai runner wo run ask >/dev/null
    grep -qx 'Bash(pwd)' "$BATS_TEST_TMPDIR/claude.args"
    grep -qx 'Bash(git log \*)' "$BATS_TEST_TMPDIR/claude.args"
}

@test "send: the agent gets no tools and no prompts unless asked" {
    skogai runner send -p q -s answer >/dev/null
    [[ $(arg_after --tools) == "" ]]
    [[ $(arg_after --permission-mode) == dontAsk ]]
    refute_arg --allowedTools
    skogai runner send -p q -s answer -t Bash -a 'Bash(ls)' --plugin-dir /p >/dev/null
    [[ $(arg_after --tools) == Bash ]]
    [[ $(arg_after --allowedTools) == 'Bash(ls)' ]]
    [[ $(arg_after --plugin-dir) == /p ]]
}

@test "send: without a schema stdout is the text, no schema is passed" {
    run skogai runner send -p q
    assert_status 0
    [[ $output == done ]]
    refute_arg --json-schema
}

@test "send: a schema can be a path, --raw prints the envelope" {
    echo '{"type": "object"}' >mine.json
    run skogai runner send -p q -s mine.json --raw
    assert_status 0
    [[ $(arg_after --json-schema) == '{"type":"object"}' ]]
    [[ $(jq -r .result <<<"$output") == done ]]
}

@test "send: no envelope from claude exits 1 and says so" {
    export STUB_ENVELOPE=
    run skogai runner send -p q -s answer
    assert_status 1
    assert_output_has "no result envelope"
    export STUB_ENVELOPE='Not logged in'
    run skogai runner send -p q -s answer
    assert_status 1
    assert_output_has "Not logged in"
}

@test "send: an envelope without structured output exits 1" {
    export STUB_ENVELOPE='{"is_error": false, "result": "ignored the schema"}'
    run skogai runner send -p q -s answer
    assert_status 1
    assert_output_has "no structured output"
}

@test "send: a missing file is a usage error" {
    run skogai runner send -p q -f nosuch.txt -s answer
    assert_status 2
    assert_output_has "no such file: nosuch.txt"
}

@test "schemas: every schema is an object schema with required fields" {
    local f
    for f in "$(module_dir)"/schemas/*.json; do
        jq -e '.type == "object" and (.required | length > 0)' "$f" >/dev/null || { echo "bad schema: $f" >&2; return 1; }
    done
}

@test "improve: one refused path and --apply writes nothing" {
    printf 'old\n' >f.txt
    ok '{"summary": "s", "files": [{"path": "f.txt", "content": "new\n"}, {"path": "other.txt", "content": "x"}]}'
    run skogai runner improve -f f.txt --apply "change it"
    assert_status 2
    [[ $(cat f.txt) == old && ! -e other.txt ]]
}

@test "improve: unchanged files are an empty patch, exit 0" {
    printf 'old\n' >f.txt
    ok '{"summary": "s", "files": [{"path": "f.txt", "content": "old\n"}]}'
    run skogai runner improve -f f.txt "change it"
    assert_status 0
    assert_output_has "empty patch"
}

@test "improve: without -f it hands over this module, with the argc spec as context" {
    ok '{"summary": "s", "files": []}'
    run skogai runner improve "change it"
    assert_status 0
    grep -q '<file path="[^"]*/runner/argc.sh">' "$BATS_TEST_TMPDIR/claude.stdin"
    grep -q '<file path="[^"]*/runner/module.md">' "$BATS_TEST_TMPDIR/claude.stdin"
    grep -q '<file path="[^"]*/docs/argc/specification.md">' "$BATS_TEST_TMPDIR/claude.stdin"
}

@test "wo run: the workorder's model, and -m over it" {
    skogai runner wo new ask -s answer >/dev/null
    yq -i --front-matter=process '.model = "opus"' "$LOCAL/workorders/ask.md"
    skogai runner wo run ask >/dev/null
    [[ $(arg_after --model) == opus ]]
    skogai runner wo run ask -m haiku >/dev/null
    [[ $(arg_after --model) == haiku ]]
}

@test "wo run: a failed worker leaves no result, the workorder stays open" {
    skogai runner wo new ask -s answer >/dev/null
    export STUB_ENVELOPE='{"is_error": true, "result": "boom"}'
    run skogai runner wo run ask
    assert_status 1
    [[ ! -e $LOCAL/workorders/ask.result.json && ! -e $LOCAL/workorders/ask.result.json.tmp ]]
    run skogai runner wo ls
    assert_output_has "open  ask"
}

@test "wo run: a path works, a file that is not a workorder or none is refused" {
    skogai runner wo new ask -s answer >/dev/null
    run skogai runner wo run .skogai/workorders/ask.md
    assert_status 0
    printf -- '---\ntype: note\n---\n' >note.md
    run skogai runner wo run note.md
    assert_status 2
    assert_output_has "not a workorder"
    run skogai runner wo run nosuch
    assert_status 2
    assert_output_has "no workorder: nosuch"
}

@test "wo: files given in a subdir are found when run from anywhere" {
    mkdir sub
    echo input >sub/in.md
    (cd sub && skogai runner wo new ask -s answer -f in.md >/dev/null)
    mkdir -p other
    (cd other && skogai runner wo run ask >/dev/null)
    grep -q '<file path="sub/in.md">' "$BATS_TEST_TMPDIR/claude.stdin"
}

@test "journal prompts: --md is markdown, a missing journal is a usage error" {
    journal_fixture
    run skogai runner journal prompts --md --last 1
    assert_output_has "## 2026-10-22 10:05 · turn a2"
    assert_output_has $'second\ntwo lines'
    rm "$LOCAL/journal.md"
    run skogai runner journal prompts
    assert_status 2
}

@test "journal harvest: one worker per --turns chunk, every item in one array" {
    journal_fixture
    ok '{"items": [{"kind": "todo", "text": "t", "turn": "a1"}]}'
    run --separate-stderr skogai runner journal harvest --turns 1
    assert_status 0
    [[ $(calls) == 2 ]]
    [[ $(jq length <<<"$output") == 2 ]]
    grep -q 'turn a2' "$BATS_TEST_TMPDIR/claude.stdin"
    [[ $(<"$BATS_TEST_TMPDIR/claude.stdin") != *"turn a1"* ]]
}

@test "journal harvest: a journal without turns is an empty array, no worker" {
    mkdir -p "$LOCAL"
    echo "# nothing yet" >"$LOCAL/journal.md"
    run --separate-stderr skogai runner journal harvest
    assert_status 0
    [[ $output == "[]" ]]
    [[ ! -e $BATS_TEST_TMPDIR/claude.calls ]]
    run skogai runner journal prompts
    assert_status 0
}
