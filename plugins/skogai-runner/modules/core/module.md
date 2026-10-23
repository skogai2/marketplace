---
type: module
name: core
description: config across layers, and finding, installing and scaffolding modules
command: argc.sh
tools: [git, yq, argc]
requires: []
files:
  - templates/
  - tests/helper.bash
  - tests/contract.bats
config:
  module:
    install: local
---

# core

the module every other one stands on. `skogai config` and `skogai module` are
its commands; `skogai core ...` is the same thing spelled out. what a module
is, how it is found, installed, configured and run: `docs/module.md` in the
skogai-runner plugin.

| command | |
|---|---|
| `config get/set/unset/list/env/files` | config across module, system, global, local and `module.local.md` layers |
| `module ls` | every module found, its layer and description |
| `module show <name>` | its manifest, where it is, what it is missing |
| `module check [name\|path]...` | check modules against the spec |
| `module add <name\|path> [--to] [--apply]` | copy a module into `.skogai/modules` or the global dir |
| `module diff <name>` | an installed copy against its source |
| `module new <name> <description> [--to]` | scaffold from `templates/module/` |
| `module test [name]... [--filter]` | for each module the contracts of core and what it requires, then its own `tests/` (bats) |
| `module build [--to] [--shell]` | generate `skogai` for a shell: one argc file over every module, man pages, completions |
| `module env <name>` | the env a module's command runs with |
| `module command <name>` | the path of a module's argc script |

## config

| key | default | |
|---|---|---|
| `core.module.install` | `local` | where `module add` and `module new` put a module without `--to`: `local` or `global` |

`templates/main.sh` is what `module build` fills in. `docs/argc/` is the argc
reference every module's command is written against.

`templates/module/` is what `module new` scaffolds (`_name_` in a path becomes
the module's name); edit an installed copy to change it for one repo.

## tests

`tests/helper.bash` is the base every module's tests load, and
`tests/contract.bats` is what every module is held to; both are offered, so an
installed core keeps them. `tests/core.bats` is core's own.
