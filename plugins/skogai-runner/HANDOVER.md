# skogai-runner: handover

from a skogai session, 2026-10-18 (skogai branch `bridge-cse_013WWYqpWeqHxJuZ6CaqYtLf`, `9212a5c` added it, `94e47d2` moved it here).

## intent

skogix's words: "you will be the one writing context, your intentions and will be the one managing yourself". this is the first iteration of that: your own command runner, the same commands everywhere, for handing strictly typed work to other agents. start by making it self-improving, so agents do the heavy lifting.

## what it is

- `scripts/main.sh`: template for the main runner `~/Argcfile.sh`. `argc register <file> <name>` links an argc script into `~/.config/argc/commands/` and `sync` regenerates the main file with one forwarding recipe per script (`argc <name> ...`), delegating help and completion to the script itself. any argc script can be registered: `argc config` (dash-skogai's `skogai-config`) is one.
- `scripts/runner.sh`, `argc runner`: the core recipes, all built on `send :: (prompt, [file], schema) -> json` (`claude -p --json-schema`, read `.structured_output`).
- `scripts/marketplace.sh`, `argc marketplace`: plugin recipes for this marketplace (`new`, `check`, `json`, `evals`, `improve`). it used to be the repo root `Argcfile.sh`; the repo has none now, so `~/Argcfile.sh` applies inside it too.
- skill `argc` (how to use and extend all of it), schemas in `schemas/`, the argc docs in `docs/`.
- `.skogai/workorders/smoke-test.*`: a worked example, a workorder and its typed result.
- `TODO.md`: what's needed before it runs here.

usage is in `skills/argc/SKILL.md`, and `argc --help` is the source of truth.

## decisions

- **pure by default**: `improve` prints a patch and exits `1`, like `skogai plan`. only `--apply` writes. scaffolds (`wo new`, `marketplace new`) create new files and refuse to overwrite.
- **whole files, derived patch**: workers return complete files (schema `edit`), and the runner builds the diff with `diff -u`, so a bad hunk from a model can't happen. `--apply` writes those files directly. paths not handed over are refused.
- **no tools by default**: inputs are inlined as `<file path>` blocks. `--tools` opts in.
- **one main runner, many scripts**: each script owns one domain and runs standalone with `argc --argc-run`; the main runner only forwards. scripts resolve their own files from their real path and run from the caller's directory.
- **workorders are blobs of text**: markdown, frontmatter for `schema`/`files`/`tools`. they go wherever we want.

## verified (skogai repo, haiku)

- `argc runner check` (argc parse, shellcheck, schemas, `claude plugin validate`) and `argc marketplace check`: pass, from anywhere under `~`.
- the main runner: forwarding, help and completion (subcommands, schema names, file paths) through `~/Argcfile.sh`.
- `send -s answer`, `wo new` + `wo run -s check`: typed output as expected.
- the loop: smoke-test findings went into `plugin improve` (now `argc marketplace improve`) and a patch came out. 2 of 3 hunks were right. one inverted the exit-code meaning and was rejected. **review patches, don't blind `--apply`.**

## not verified

- anything as the `claude` user or from `~/.config/mise`: see `TODO.md`.
- `argc marketplace evals`: there are no evals yet.
- `argc runner improve --apply`, the `wo run` failure path, `journal harvest` since the move.
