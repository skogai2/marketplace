---
name: runner
description: Hand typed work to other agents with `skogai runner` (send, improve, wo, journal). Use when delegating a bounded question or a file edit, writing or running a workorder, or reading back or harvesting a session journal, instead of doing that work inline.
allowed-tools: Bash(skogai runner send *), Bash(skogai runner wo ls), Bash(skogai runner journal prompts *)
---

# runner

`skogai runner` is the runner module (`${CLAUDE_PLUGIN_ROOT}/modules/runner/`).
its `module.md` is the reference; `skogai runner <cmd> --help` is the source of
truth. every agent call is one function:

```
send :: (prompt, [file], schema) -> json
```

## when

- a bounded question about files you can name: `skogai runner send -p "<q>" -f <file>... -s answer`.
- findings over files: `-s check`, rows of `{path, line, rule, severity, message}`.
- an edit you want a worker to draft: `skogai runner improve -f <file>... "<request>"`. it prints the patch and exits `1`; read it, then rerun with `--apply` before the request. **review patches, don't blind `--apply`.**
- work worth keeping as a record: `skogai runner wo new <name> -s <schema> -f <file>...`, write the question into `.skogai/workorders/<name>.md`, then `skogai runner wo run <name>`.
- a worker that needs tools to try skogai things (run modules, change config): `wo new <name> -t Bash -a 'Bash(skogai *)' --sandbox`. it runs in a fresh sandbox at `.skogai/tmp/sandbox/<name>` with every module installed and its own config, kept afterwards to look at. a tool in `-t` that no `-a` pattern allows is denied.
- what the user actually asked in a session: `skogai runner journal prompts --last N`.

## rules

- options go before the positional request: `improve -f a -f b --apply "<request>"`. everything after the request is the request.
- one bounded question per call or workorder; inputs are files, never "go look around". workers get no tools unless `--tools` says so.
- output is a schema (`schemas/`: `answer`, `check`, `edit`, `harvest`), so the result is checkable without reading prose. a new schema is small, `additionalProperties: false`, every field required.
- exit `0` ok or empty patch, `1` agent error or unapplied patch, `2` usage.
- `runner.model` (default `sonnet`) picks the model: `skogai config set runner.model haiku`.
