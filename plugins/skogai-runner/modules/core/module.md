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
| `module env <name>` | the env a module's command runs with |
| `module command <name>` | the path of a module's argc script |

## config

| key | default | |
|---|---|---|
| `core.module.install` | `local` | where `module add` and `module new` put a module without `--to`: `local` or `global` |

`templates/module/` is what `module new` scaffolds; edit an installed copy to
change it for one repo.
