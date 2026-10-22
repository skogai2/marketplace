# argc runner: handover

from a skogai session, 2026-10-18 (skogai branch `bridge-cse_013WWYqpWeqHxJuZ6CaqYtLf`, `9212a5c` added it, `94e47d2` moved it here).

## intent

skogix's words: "you will be the one writing context, your intentions and will be the one managing yourself". this is the first iteration of that: your own command runner, the same commands everywhere, for handing strictly typed work to other agents. start by making it self-improving, so agents do the heavy lifting.

## what it is

- `scripts/runner.sh`: the core recipes, all built on `send :: (prompt, [file], schema) -> json` (`claude -p --json-schema`, read `.structured_output`).
- skill `argc` (how to use and extend the runner), schemas in `schemas/`, the argc docs in `docs/`.
- `scripts/main.sh`: template for a main `~/Argcfile.sh`. `argc register <file> <name>` links an argc script into `~/.config/argc/commands/` and `sync` regenerates the main file with one forwarding recipe per command (`argc <name> ...`), delegating help and completion to the script itself.
- the marketplace root `Argcfile.sh` forwards `send`/`improve`/`wo`/`journal` to the core and keeps the `plugin` recipes.
- `.skogai/workorders/smoke-test.*`: a worked example, a workorder and its typed result.
- `TODO.md`: what's needed before it runs here.

usage is in `skills/argc/SKILL.md`, and `argc --help` is the source of truth.

## decisions

- **pure by default**: `improve` prints a patch and exits `1`, like `skogai plan`. only `--apply` writes. scaffolds (`wo new`, `plugin new`) create new files and refuse to overwrite.
- **whole files, derived patch**: workers return complete files (schema `edit`), and the runner builds the diff with `diff -u`, so a bad hunk from a model can't happen. `--apply` writes those files directly. paths not handed over are refused.
- **no tools by default**: inputs are inlined as `<file path>` blocks. `--tools` opts in.
- **workorders are blobs of text**: markdown, frontmatter for `schema`/`files`/`tools`. they go wherever we want.

## verified (skogai repo, haiku)

- `argc check`: argc parse, shellcheck, schemas, `claude plugin validate`: all pass.
- `send -s answer`, `wo new` + `wo run -s check`: typed output as expected.
- the loop: smoke-test findings went into `plugin improve` and a patch came out. 2 of 3 hunks were right. one inverted the exit-code meaning and was rejected. **review patches, don't blind `--apply`.**

## not verified

- anything as the `claude` user or from `~/.config/mise`: see `TODO.md`.
- `plugin eval`: there are no evals yet.
