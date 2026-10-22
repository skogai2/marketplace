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
