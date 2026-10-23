---
name: module
description: Find, run, install, configure and create skogai modules (`skogai <name> ...`, `skogai module ...`, `skogai config ...`). Use when asked to add, change or package a skogai capability as a module, when a module's command or config is involved, or when something should land in `.skogai/` as a unit.
allowed-tools: Bash(skogai module ls), Bash(skogai module show *), Bash(skogai module check *), Bash(skogai module diff *), Bash(skogai config get *), Bash(skogai config list *), Bash(skogai config files *), Bash(skogai module test *)
---

# skogai modules

`skogai` (on `PATH` from this plugin's `bin/`) runs modules: `skogai <name> ...`
is a module's command, `skogai config` and `skogai module` are core's. argc is the engine, `skogai` the runner. the
spec is `${CLAUDE_PLUGIN_ROOT}/docs/module.md`; read it before creating or
changing a module. `modules/memory` is the worked example.

## using

- `skogai module ls`: what exists and where; `skogai module show <name>`: its manifest and what it is missing.
- `skogai <name> --help` is the source of truth for a module's recipes.
- `skogai config get <name>.<key> --show-origin`: a setting and the layer it came from.
- a shell gets `skogai` from `skogai module build`: it prints the `PATH`, `MANPATH` and `ARGC_COMPLETIONS_PATH` lines; give them to the user, don't write them into their shell config.
- to try modules installed, away from real config: `skogai module sandbox [dir]` installs every module into a throwaway repo with its own layers and prints the env lines to switch into it. your own commands go through `<dir>/run <cmd>...` (default `/tmp/skogai/run`): the env does not persist between Bash calls, so don't eval the lines. rerun `skogai module sandbox` for a fresh one.
- installing is an offer: `skogai module add <name>` prints the plan and exits `1`; only `--apply` copies. never overwrite a `keep` file; show `skogai module diff <name>` instead.

## creating

1. `skogai module new <name> "<description>"`: scaffolds `.skogai/modules/<name>/`.
2. fill in `module.md`: `tools`, `files`, `config` defaults, and a body explaining every key.
3. write `argc.sh`: read paths and config from `SKOGAI_MODULE_DIR`, `SKOGAI_LOCAL_DIR` and `SKOGAI_<NAME>_<KEY>`, never `$PWD` or its own path. pure by default, `--apply` for changes to existing files. exit `0` ok, `1` finding or unapplied change, `2` usage.
4. tests in `tests/*.bats`, starting with `load "$SKOGAI_TEST_HELPER"` (spec: tests). `skogai module test <name>` runs the contract every module is held to, then them; both must pass.
5. to ship it, move the directory to a plugin's `modules/`.

a capability that needs more than one module's files is two modules with `requires:`, not one bigger one.
