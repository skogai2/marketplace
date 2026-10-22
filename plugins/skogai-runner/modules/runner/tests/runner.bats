#!/usr/bin/env bats
# claude is a stub: it records its args and stdin, and prints $STUB_ENVELOPE.

load "$SKOGAI_TEST_HELPER"

setup() {
    skogai_setup
    mkdir -p "$BATS_TEST_TMPDIR/stub"
    cat >"$BATS_TEST_TMPDIR/stub/claude" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/claude.args"
cat >"$BATS_TEST_TMPDIR/claude.stdin"
printf '%s' "$STUB_ENVELOPE"
SH
    chmod +x "$BATS_TEST_TMPDIR/stub/claude"
    PATH="$BATS_TEST_TMPDIR/stub:$PATH"
    ok '{"answer": "42"}'
}

# the envelope claude -p --output-format json would print, with structured output $1
ok() { export STUB_ENVELOPE="{\"is_error\": false, \"result\": \"done\", \"structured_output\": $1}"; }

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
    run skogai runner journal prompts
    assert_status 0
    [[ $(jq -s length <<<"$output") == 2 ]]
    [[ $(jq -rs '.[1].prompt' <<<"$output") == $'second\ntwo lines' ]]
    refute_output_has "an answer"
    run skogai runner journal prompts --last 1
    [[ $(jq -s length <<<"$output") == 1 ]]
}
