---
name: argc
description: Use the skogai command runner (`argc`: `argc runner`, `argc marketplace`, `argc skogai`, the `skogai` modules and other registered scripts) to hand typed work to other agents, run workorders, manage marketplace plugins, and extend the runner. Use when delegating a bounded question or an edit, when a recipe is missing, or when asked to add or change an argc script.
allowed-tools: Bash(argc runner *), Bash(argc ls), Bash(argc --argc-run ${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh *)
---

# argc

one `argc` for everything. `~/Argcfile.sh` is the main runner: every registered argc script is a subcommand of it, `argc <name> <cmd>`, run from the directory you call it in. `argc ls` lists what is registered; `argc <name> <cmd> --help` is the source of truth, this skill only says how to use them.

| script | registered as | what |
|---|---|---|
| `${CLAUDE_PLUGIN_ROOT}/scripts/main.sh` | the main runner itself | `register`, `unregister`, `ls`, `sync` |
| `${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh` | `argc runner` | typed agent io: `send`, `improve`, `wo`, `journal`, `check` |
| `${CLAUDE_PLUGIN_ROOT}/scripts/marketplace.sh` | `argc marketplace` | skogai-marketplace plugins: `new`, `check`, `json`, `evals`, `improve` |
| `${CLAUDE_PLUGIN_ROOT}/modules/core/argc.sh` | `argc skogai`, or `skogai` from the plugin's `bin/` | core module: `config get/set/list/env/files`, `module ls/show/add/diff/new`. see `modules/core/module.md` |

without the main runner (outside `~`, or not installed), run a script directly: `argc --argc-run ${CLAUDE_PLUGIN_ROOT}/scripts/runner.sh <cmd>`. a repo with its own `Argcfile.sh` shadows `~/Argcfile.sh` inside it.

## the main runner

- `argc register <file> <name>`: links the script into `~/.config/argc/commands/<name>.sh` and syncs. name is lowercase, one segment.
- `argc sync`: rewrites `~/Argcfile.sh` from `main.sh` plus one forwarding recipe per registered script; help and completion come from the script itself. `sync` runs the copy in `~/Argcfile.sh`, so a change to `main.sh` takes effect on the second `sync`.
- install: `argc --argc-run ${CLAUDE_PLUGIN_ROOT}/scripts/main.sh register <path>/scripts/runner.sh runner`. register a local checkout, not the plugin cache: the cache path changes with every version.

## the contract

the agent call behind `argc runner send` is one function:

```
send :: (prompt, [file], schema) -> json
```

- files are inlined, the worker gets no tools unless `--tools` says so.
- `--schema` names a file in `${CLAUDE_PLUGIN_ROOT}/schemas/` or a path. stdout is the json object; envelopes are logged to `.skogai/logs/argc/`.
- file arguments are relative to the current directory; workorders, journal and logs live in `.skogai/` at the root of the current git repo (the current directory outside one).
- exit `0` ok or empty patch, `1` agent error or a patch printed but not applied (like `skogai plan`), `2` usage.

## recipes

| recipe | use |
|---|---|
| `argc runner send -p <q> -f <file>... -s answer` | one bounded question, short checkable answer |
| `argc runner send -s check -f <file>...` | findings as `{path, line, rule, severity, message}` |
| `argc runner improve <request> [-f file]... [--apply]` | whole-file edits from a worker, patch derived by `diff -u`. prints the patch unless `--apply` |
| `argc runner wo new <name> -s <schema> -f <file>...` | write `.skogai/workorders/<name>.md` |
| `argc runner wo run <name>` | run it, result in `<name>.result.json` |
| `argc runner journal prompts [file] [--last N] [--md]` | only the user's input from a session journal, one json row per turn |
| `argc runner journal harvest [file] [--last N] [--turns N]` | workers pick decisions, docs, todos, learnings out of a journal (schema `harvest`) |
| `argc runner check` | argc parse, shellcheck, schemas, this plugin |
| `argc marketplace new <name> <description>` | scaffold `plugins/<name>` |
| `argc marketplace check [name]...` | validate plugins, then `generate-marketplace-json.sh --check` |
| `argc marketplace json` | regenerate `.claude-plugin/marketplace.json` |
| `argc marketplace evals <name>` | run a plugin's evals |
| `argc marketplace improve <name> <request> [--apply]` | `argc runner improve` over every file of a plugin |

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

## extending

a recipe is a bash function with `# @cmd` above it; `foo::bar` is `argc <name> foo bar`. flags and options become `$argc_<name>`. spec: `${CLAUDE_PLUGIN_ROOT}/docs/specification.md`, the rest of `docs/` covers variables, completions, help format and macros.

- recipes every repo can use go in `runner.sh`; recipes for one repo or tool go in their own script, registered under its own name (`marketplace.sh` is the example).
- a script resolves its own files from `realpath "${BASH_SOURCE[0]}"`, never `$PWD`: registered scripts run from the caller's directory, through a symlink.
- don't name a script `Argcfile.sh`: argc then runs it from its own directory instead of the caller's.
- don't name a recipe after a bash builtin (`eval`, `cd`, `exec`): argc's generated code calls them.
- pure by default. a recipe that writes takes `--apply`, and without it prints what it would do.
- a missing recipe is a gap: add it, or run `argc runner improve "<what it should do>" -f <script>` and review the patch.
- keep a new schema small, `additionalProperties: false`, every field required.
- run `argc runner check` after a change. recipes are found at run time; `argc sync` is only needed after registering a script or changing its `@describe`.
