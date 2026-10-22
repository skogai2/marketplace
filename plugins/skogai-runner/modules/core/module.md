---
type: module
name: core
description: config across layers, and finding, installing and scaffolding modules
command: argc.sh
tools: [git, yq, argc]
requires: []
files:
  - templates/
config:
  module:
    install: local
---

# core

the module every other one stands on. `skogai config` and `skogai module` are
its commands; `skogai core ...` is the same thing spelled out.

## a module

a directory named after the module, with a `module.md`:

| field | what |
|---|---|
| `type` | `module` |
| `name` | lowercase, one segment, same as the directory |
| `description` | one line |
| `command` | optional: its argc script, run as `skogai <name> ...` |
| `tools` | executables it needs on `PATH` |
| `requires` | other modules it needs |
| `files` | what it offers besides `module.md` and `command`: files, or dirs taken whole |
| `config` | defaults, read as `<name>.<key>` through `skogai config` |

## where modules are

installed local (`.skogai/modules/`), installed global
(`~/.config/skogai/modules/`), then sources (`$SKOGAI_MODULE_PATH`, by default
the plugin's `modules/`). the first by a name wins, so an installed copy
shadows its source and a local one shadows a global one.

## config

`core.module.install` (`local` or `global`) is where `module add` and
`module new` put a module when `--to` is not given. an installed module's
`module.local.md` overrides its defaults: `skogai config set --module core
core.module.install global`.

## what a module's command gets

`skogai <name> ...` runs the command with `skogai module env <name>` exported:

| var | what |
|---|---|
| `SKOGAI_MODULE` | its name |
| `SKOGAI_MODULE_DIR` | its directory: where its `files:` are, installed or source |
| `SKOGAI_LOCAL_DIR` | the local `.skogai`, absolute |
| `SKOGAI_CONFIG_DIR` | the global dir, absolute |
| `SKOGAI_<NAME>_<KEY>` | each of its own resolved keys: `memory.stale-days` is `SKOGAI_MEMORY_STALEDAYS` |

a command needs no lookups of its own; `: "${SKOGAI_MODULE_DIR:?}"` makes it
refuse to run outside `skogai`. `modules/memory` is the worked example.
