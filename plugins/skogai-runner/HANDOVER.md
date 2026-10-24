# skogai-runner: handover

started from a skogai session, 2026-10-18 (skogai branch `bridge-cse_013WWYqpWeqHxJuZ6CaqYtLf`); rebuilt around modules 2026-10-22/23.

## intent

skogix's words: "you will be the one writing context, your intentions and will be the one managing yourself". the runner is that: the same commands everywhere, for handing strictly typed work to other agents, built so agents do the heavy lifting and the runner improves itself.

## what it is

`skogai` is the runner, argc the engine under it. everything it does is a module.

- `docs/module.md`: the spec. a module is a dir with a `module.md` (command, tools, requires, files, config defaults) and usually an argc script; `skogai <name>` runs it with its env.
- `bin/skogai`: on the Bash tool's `PATH` in sessions. dispatches to modules found at run time; anything else goes to core.
- `modules/core`: config across layers, and `skogai module ls|show|check|test|build|add|diff|new|env`. owns the test base (`tests/helper.bash`, `tests/contract.bats`), the templates and the argc docs (`docs/argc/`).
- `modules/runner`: typed agent io, `send :: (prompt, [file], schema) -> json`, plus `improve`, `wo`, `journal`.
- `modules/memory`: `.skogai/memory/`, the worked example of a small module.
- `modules/type`: instance schemas. a module requiring it offers `schema/<x>.json` and globs its instances with `<module>.schema.<x>`; `skogai type check` validates their frontmatter with ajv.
- the marketplace repo's own `.skogai/modules/marketplace`: plugin recipes, a local module, so it exists only in that repo.
- skills `module` (use and create modules) and `runner` (delegate work).

## decisions

- **modules, not scripts**: a module is the argc script plus the files it works with and its config defaults, copied into `.skogai/` as a unit. found local, then global, then sources; runs from wherever found.
- **skogai is the runner**: no `~/Argcfile.sh` and no registry. `bin/skogai` resolves modules dynamically; `skogai module build` generates the static file a shell needs for help, completion and man pages (the old-core build trick, `ARGC_COMPLETIONS_PATH` instead of a completions repo entry).
- **a module reads its world from env**: `SKOGAI_MODULE_DIR`, `SKOGAI_LOCAL_DIR`, `SKOGAI_<NAME>_<KEY>`. no lookups of its own; it refuses to run outside `skogai`.
- **core sets the test base**: every module you require runs its contract against you (core's always), then its own tests, all isolated from the caller's config.
- **pure by default**: `improve`, `module add`, `memory index` print a plan and exit `1`; only `--apply` writes. scaffolds create new files and refuse to overwrite.
- **whole files, derived patch**: workers return complete files (schema `edit`), the runner builds the diff with `diff -u`. paths not handed over are refused.
- **no tools by default**: inputs are inlined as `<file path>` blocks. `--tools` opts in.
- **installing is an offer**: changed installed files are kept, `module diff` shows how.

## verified

- `skogai module test` from the marketplace repo: core 45, runner 36, memory 17, bats 1.14 via mise. runner tests stub `claude`. the `marketplace` workflow's `modules` job and the pre-commit hook run them; the workflow job has not run on GitHub yet.
- a fresh `module new` scaffold passes the contract and its own test.
- `skogai module sandbox`: eval in bash and source in fish give a shell where every module is `local` in `/tmp/skogai/repo` and `skogai` is the sandbox build.
- `wo run` with `sandbox: true`, `tools: Bash` and `allow:` against haiku: the worker ran `pwd` and `skogai module ls` in its own sandbox (from inside `/tmp/skogai/run`, since the global runner copy shadows the source).
- the built `skogai`: help, runs, completion (including module choices like runner's schemas) through `ARGC_COMPLETIONS_PATH`, man pages.
- `skogai memory ls/stale/index` read-only against `~/skogai`; `skogai marketplace check` against this repo.
- earlier, with the pre-module runner: `send -s answer`, `wo run -s check`, and `improve` producing a patch (2 of 3 hunks right, one inverted an exit code). **review patches, don't blind `--apply`.**

## not verified

- `runner improve --apply` and `journal harvest` against a real model since the port.
- `skogai` as the `claude` user, and from a shell with the build's env lines in place.
