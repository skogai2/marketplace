---
name: argc
description: Use the skogai command runner (`argc`, root Argcfile.sh) to hand typed work to other agents, run workorders, and improve the runner or a plugin. Use when delegating a bounded question or an edit, when a recipe is missing, or when asked to extend Argcfile.sh.
---

# argc

`argc` runs recipes from the nearest `Argcfile.sh` up the tree, so the same commands work from any directory in the repo. `argc --help` and `argc <cmd> --help` are the source of truth; this skill only says how to use them.

## the contract

the agent call behind `send` is one function:

```
send :: (prompt, [file], schema) -> json
```

- files are inlined, the worker gets no tools unless `--tools` says so.
- `--schema` names a file in `plugins/skogai-runner/schemas/` or a path. stdout is the json object; envelopes are logged to `.skogai/logs/argc/`.
- exit `0` ok or empty patch, `1` agent error or a patch printed but not applied (like `skogai plan`), `2` usage.

## recipes

| recipe | use |
|---|---|
| `argc send -p <q> -f <file>... -s answer` | one bounded question, short checkable answer |
| `argc send -s check -f <file>...` | findings as `{path, line, rule, severity, message}` |
| `argc improve <request> [-f file]... [--apply]` | whole-file edits from a worker, patch derived by `diff -u`. prints the patch unless `--apply` |
| `argc wo new <name> -s <schema> -f <file>...` | write `.skogai/workorders/<name>.md` |
| `argc wo run <name>` | run it, result in `<name>.result.json` |
| `argc plugin new <name> <description>` | scaffold `plugins/<name>` |
| `argc plugin check [name]`, `argc plugin eval <name>` | validate, run evals |
| `argc plugin improve <name> <request> [--apply]` | `improve` over every file of a plugin |
| `argc check` | argc parse, shellcheck, schemas, plugins |

## workorders

one bounded question per workorder. inputs are listed as files, never "go look around". output is a schema, so the result is checkable without reading prose.

```markdown
---
type: workorder
title: <name>
schema: answer
tools: ""
files:
  - path/to/input.md
---

<one bounded question>
```

## extending the runner

a recipe is a bash function with `# @cmd` above it; `foo::bar` is `argc foo bar`. flags and options become `$argc_<name>`. spec: `~/.local/src/argc/docs/specification.md`.

- pure by default. a recipe that writes takes `--apply`, and without it prints what it would do.
- a missing recipe is a gap: add it, or run `argc improve "<what it should do>"` and review the patch.
- keep a new schema small, `additionalProperties: false`, every field required.
- run `argc check` after a change.
