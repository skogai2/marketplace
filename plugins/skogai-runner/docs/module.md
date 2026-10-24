# skogai modules

a module is one thing skogai can do, packaged so it can be found, run,
configured and copied into a repo as a unit. the argc script is one part of
it; the files it works with and its config defaults are the rest.

`skogai module check` enforces what this spec says a module must be.
`modules/core` and `modules/memory` are the reference modules.

## layout

```
<name>/
  module.md        required: manifest (frontmatter) and what it is (body)
  argc.sh          optional: the command, named by `command:`
  templates/ ...   optional: anything it offers, named by `files:`
  tests/*.bats     its own tests; not offered unless listed in `files:`
  tests/fixtures/  examples its schemas are held to (with `type`)
  module.local.md  local overrides, never shipped
```

the directory name is the module name.

## module.md

```markdown
---
type: module
name: memory
description: one fact per file, each with a stale_after; expired ones get decided on
command: argc.sh
tools: [yq]
requires: [core]
files:
  - templates/
config:
  dir: memory
  stale-days: 30
---

# memory

what it is, when to use it, what each config key means.
```

| field | | type | meaning |
|---|---|---|---|
| `type` | required | `module` | |
| `name` | required | string | lowercase, one segment (`^[a-z][a-z0-9]*$`), same as the directory |
| `description` | required | string | one line, what it is; shown by `module ls` |
| `command` | optional | path | its argc script, relative to the module dir; `skogai <name>` runs it |
| `tools` | optional | list | executables it needs on `PATH` |
| `requires` | optional | list | modules it needs; every module but `core` requires `core` |
| `files` | optional | list | paths it offers beyond `module.md` and `command`; a path ending in `/` is a whole directory |
| `config` | optional | map | config defaults, read as `<name>.<key>` |

a module consists of exactly `module.md`, `command` and `files`. nothing else
is copied on install; anything else in the directory is the source's own.

the body is prose for humans and agents: what the module is, every config key
and what it means, and anything a user decides when installing it.

## names

- `core`, `config`, `module` and `help` are reserved: `skogai config ...` is
  always core.
- config keys are lowercase; `.` is a relation and `-` is part of a name, so
  `memory.stale-days` is `SKOGAI_MEMORY_STALEDAYS` as env.

## where modules are found

in this order, the first module by a name wins:

| layer | where |
|---|---|
| `local` | `.skogai/modules/` at the git root (or `$SKOGAI_LOCAL_DIR/modules`) |
| `global` | `~/.config/skogai/modules/` (or `$SKOGAI_CONFIG_DIR/modules`) |
| `source` | each dir on `$SKOGAI_MODULE_PATH`, by default the plugin's `modules/` |

a module runs from wherever it is found; installing is not needed to use it.
an installed copy shadows its source, a local one shadows a global one.

## installing

installing copies a module into `local` or `global` so it can be edited there.
it is an offer, never a takeover:

- `skogai module add <name|path>` prints the plan, one line per file: `add`
  (missing, will copy), `same`, or `keep` (there and different, never
  overwritten). it exits `1` if anything would be added.
- `--apply` copies. `--to local|global` picks the layer, default
  `core.module.install`.
- `skogai module diff <name>` shows how an installed copy differs from its source.
- nothing outside `.skogai/` (local) or `~/.config/skogai/` (global) is written.

## config

a module's keys live under its name. the layers, later wins:

1. `config:` in every found `module.md` (defaults)
2. system, global, local: git-config files `config` in `/etc/skogai`,
   `~/.config/skogai`, `.skogai`
3. `config:` in each module's `module.local.md`
4. `--file` layers (`skogai config` only)
5. `SKOGAI_*` env

`skogai config set --module <name> <name>.<key> <value>` writes a module's
`module.local.md`: beside an installed copy's `module.md`, and for a source
module in `.skogai/modules/<name>/`, never into the source.
`skogai config get <key> --show-origin` says which layer won.

## skogai

`skogai` is the runner; argc is the engine under it.

- in Claude Code sessions it is this plugin's `bin/skogai`, on the Bash tool's
  `PATH` while the plugin is enabled. it finds modules when it runs, so
  nothing needs registering. its `SessionStart` hook runs
  `skogai module build --to global` and puts the built `skogai` first on
  the Bash tool's `PATH` (via `CLAUDE_ENV_FILE`), so `skogai --help` lists
  every module found from where the session started.
- in a shell, `skogai module build` generates a static `skogai`: one argc
  file with a forwarding recipe for core's groups and every module found
  from there, so `--help`, completion and man pages cover all of them. every
  run still goes through the `bin/skogai` that built it, and a module found
  after the build runs too, only without help and completion. the build is
  throwaway, in `.skogai/tmp/skogai/` (or the global dir's): `bin/`,
  `man/man1/`, `completions/skogai.sh` for `ARGC_COMPLETIONS_PATH`, and
  `completions/skogai.{bash,zsh,fish}`. it prints the env lines for
  `PATH`, `MANPATH` and `ARGC_COMPLETIONS_PATH`; putting them in a shell, a
  `.envrc` or mise is up to the user. the first build runs the checkout's
  `bin/skogai` by path.
- `skogai module sandbox [dir]` (default `$TMPDIR/skogai`) is an empty
  skogai to try things in: `system/` and `global/` layers, a git repo
  `repo/` with every module found from here installed in its `.skogai/modules`
  (from its source when it has one) and `skogai` built there. it prints the
  env lines that switch a shell into it (`eval "$(skogai module sandbox)"`,
  fish `skogai module sandbox | source`): no `SKOGAI_*` config from outside,
  the three layer dirs, the built `skogai` on `PATH`, `cd repo`. it also
  writes `<dir>/run`, the same switch for one command (`/tmp/skogai/run
  skogai memory ls`, a shell with none), for callers whose env does not
  persist between commands, like an agent's Bash tool. rerunning replaces
  it; a dir it did not make is refused.

## the command

an argc script. `skogai <name> <args>` runs it with `argc --argc-run` from the
caller's directory, with this env (`skogai module env <name>`):

| var | |
|---|---|
| `SKOGAI_MODULE` | its name |
| `SKOGAI_MODULE_DIR` | its directory, wherever it was found; its `files:` are here |
| `SKOGAI_LOCAL_DIR` | the local `.skogai`, absolute |
| `SKOGAI_CONFIG_DIR` | the global dir, absolute |
| `SKOGAI_<NAME>_<KEY>` | each of its own resolved config keys |

rules:

- read paths and config from that env, never from `$PWD` or its own location.
  start with `: "${SKOGAI_MODULE_DIR:?run me as \`skogai <name>\`}"`.
- `# @meta binname skogai <name>` so help and man pages read right;
  `# @meta require-tools` matches `tools:`.
- a positional `~` argument takes everything after it, flags included: put
  options before it.
- exit `0` ok, `1` a finding or an unapplied change (like `diff`), `2` usage.
- pure by default: a recipe that changes an existing file takes `--apply` and
  without it prints what it would do. creating a new file is fine; overwriting
  one is refused.
- don't name a recipe after a bash builtin (`eval`, `cd`, `exec`, `set`); argc's
  generated code calls them. group them instead (`config::set`).
- other modules are called as `skogai <other> ...`, never by path.

## tests

bats. `skogai module test [name]...` runs, for each module:

1. the contract, core's `tests/contract.bats`: `module check` has no errors,
   `--help` exits 0, the command refuses to run outside `skogai` and says so, every
   `config:` default resolves under its name, `module env` is right, `add` is
   a plan and `--apply` installs, and the installed copy passes check and runs.
   then `tests/contract.bats` of each module in `requires` (not transitive)
   that has one, with `SKOGAI_TEST_MODULE` still the module under test.
2. its own `tests/*.bats`, from its source when it has one; its own
   `tests/contract.bats` is what it holds others to, not run against itself.

a module that requires `type` ships fixtures for each `schema/<x>.json` it
offers: `tests/fixtures/<x>/valid/*` and `tests/fixtures/<x>/invalid/*`, both
non-empty, in its source only (not in `files:`). type's contract checks every
valid one passes and every invalid one fails, the way `skogai type check`
checks instances (`skogai type check --schema <module>.<x> <file>...`).

a test file starts with `load "$SKOGAI_TEST_HELPER"` (core's
`tests/helper.bash`). every test then runs in an empty git repo
(`$REPO`, with `$LOCAL` its `.skogai`) with its own system and global layers
and no `SKOGAI_*` config from the caller, so nothing outside
`BATS_TEST_TMPDIR` is touched. the module under test is a source there.
helpers: `skogai`, `module_dir`, `module_field`, `assert_status`,
`assert_output_has`, `refute_output_has`, `assert_file`. a file with its own
`setup()` calls `skogai_setup` first.

set state the way a user would (`skogai config set`, `skogai module add`),
not by writing layer files.

a bare `! cmd` never fails a bats test: end a helper function with it, or
use `[[ ... ]]`. test the failure paths too: what a command refuses, and
that a failure leaves nothing behind.

## creating one

1. `skogai module new <name> "<description>"` scaffolds `module.md`, a
   hello-world `argc.sh` and `tests/<name>.bats` in `.skogai/modules/<name>/`
   (`--to global` for `~/.config/skogai/modules/`).
2. fill in `module.md`: `tools`, `files`, `config` defaults, and a body that
   explains every key.
3. write the recipes in `argc.sh` (argc spec: core's `docs/argc/specification.md`).
4. write its tests, then `skogai module test <name>`: the contracts and its
   own tests pass.
5. to ship it with a plugin, move the directory to the plugin's `modules/`.
   it is then a `source` everywhere the plugin is enabled.

## open

- modules shipped by plugins other than this one: how their `modules/` get
  onto `SKOGAI_MODULE_PATH`.
- `module update`: pulling source changes into an installed copy, file by
  file, `keep` respected.
- versions in `module.md`, and `requires` with versions.
- `command` as any executable, not only argc.
