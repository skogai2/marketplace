---
name: argc
description: Use the skogai command runner (`argc`, skogai-runner's scripts/runner.sh) to hand typed work to other agents, run workorders, and improve the runner or a plugin. Use when delegating a bounded question or an edit, when a recipe is missing, or when asked to extend Argcfile.sh.
allowed-tools: Bash(argc --argc-run ${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh *)
---

# argc

the runner is `${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh`, run from any directory:

```
argc --argc-run ${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh <cmd>
```

file arguments are relative to the current directory; workorders, journal and logs live in `.skogai/` at the root of the current git repo (the current directory outside one). a repo can forward recipes from its own `Argcfile.sh`, then `argc <cmd>` works from anywhere in it; the recipes below are written that way. when the main runner is installed (`scripts/main.sh`, `~/Argcfile.sh`), `argc runner <cmd>` works anywhere under `~` without a repo `Argcfile.sh`; `argc ls` lists what is registered. `argc <cmd> --help` is the source of truth; this skill only says how to use them.

## the contract

the agent call behind `send` is one function:

```
send :: (prompt, [file], schema) -> json
```

- files are inlined, the worker gets no tools unless `--tools` says so.
- `--schema` names a file in `${CLAUDE_PLUGIN_ROOT}/schemas/` or a path. stdout is the json object; envelopes are logged to `.skogai/logs/argc/`.
- exit `0` ok or empty patch, `1` agent error or a patch printed but not applied (like `skogai plan`), `2` usage.

## recipes

| recipe | use |
|---|---|
| `argc send -p <q> -f <file>... -s answer` | one bounded question, short checkable answer |
| `argc send -s check -f <file>...` | findings as `{path, line, rule, severity, message}` |
| `argc improve <request> [-f file]... [--apply]` | whole-file edits from a worker, patch derived by `diff -u`. prints the patch unless `--apply` |
| `argc wo new <name> -s <schema> -f <file>...` | write `.skogai/workorders/<name>.md` |
| `argc wo run <name>` | run it, result in `<name>.result.json` |
| `argc journal prompts [file] [--last N] [--md]` | only the user's input from a session journal, one json row per turn |
| `argc journal harvest [file] [--last N] [--turns N]` | workers pick decisions, docs, todos, learnings out of a journal (schema `harvest`) |
| `argc check` | argc parse, shellcheck, schemas, this plugin |

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

a recipe is a bash function with `# @cmd` above it; `foo::bar` is `argc foo bar`. flags and options become `$argc_<name>`. spec: `${CLAUDE_PLUGIN_ROOT}/docs/specification.md`, the rest of `docs/` covers variables, completions, help format and macros.

recipes that every repo can use go in `scripts/runner.sh`; recipes for one repo go in that repo's `Argcfile.sh`. don't name the core `Argcfile.sh`: argc then runs it from its own directory instead of the caller's.

- pure by default. a recipe that writes takes `--apply`, and without it prints what it would do.
- a missing recipe is a gap: add it, or run `argc improve "<what it should do>"` and review the patch.
- keep a new schema small, `additionalProperties: false`, every field required.
- run `argc check` after a change.
