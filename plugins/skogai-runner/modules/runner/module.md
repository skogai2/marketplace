---
type: module
name: runner
description: typed io for handing work to agents, prompt + files -> json matching a schema
command: argc.sh
tools: [jq, yq, git, claude]
requires: [core]
files:
  - schemas/
config:
  model: sonnet
  journal: journal.md
---

# runner

every agent call is one function:

```
send :: (prompt, [file], schema) -> json
```

files are inlined as `<file path>` blocks, the worker gets no tools unless
`--tools` says so, and stdout is the json object (`.structured_output` of
`claude -p --json-schema`). envelopes are logged to `.skogai/logs/runner/`.

| recipe | use |
|---|---|
| `send -p <q> -f <file>... -s answer` | one bounded question, short checkable answer |
| `send -s check -f <file>...` | findings as `{path, line, rule, severity, message}` |
| `improve [-f file]... [--apply] <request>` | whole-file edits from a worker, patch derived with `diff -u`; prints it unless `--apply` |
| `wo new <name> -s <schema> -f <file>...` | write `.skogai/workorders/<name>.md` |
| `wo run <name>` | run it, result in `<name>.result.json` |
| `wo ls` | workorders and whether they have a result |
| `journal prompts [file] [--last N] [--md]` | only the user's input from a journal, one json row per turn |
| `journal harvest [file] [--last N] [--turns N]` | workers pick decisions, docs, todos, learnings out of a journal |

exit `0` ok or empty patch, `1` agent error or a patch printed but not
applied, `2` usage.

## workorders

one bounded question per workorder. inputs are listed as files, never "go look
around". output is a schema, so the result is checkable without reading prose.
`files:` are relative to the repo root.

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

## config

| key | default | |
|---|---|---|
| `runner.model` | `sonnet` | model for every agent call without `--model` |
| `runner.journal` | `journal.md` | the session journal, relative to `.skogai/` |

## schemas

`schemas/*.json`, named by `--schema` (or a path): `answer`, `check`, `edit`
(what `improve` asks for), `harvest`. a new one is small,
`additionalProperties: false`, every field required.
