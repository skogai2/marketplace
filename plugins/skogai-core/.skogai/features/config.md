# Config: layered key→value in markdown frontmatter

Status: **proposed**. Nothing here is built yet. Today's per-project settings (`scripts/settings.sh`, `.claude/skogai-core.local.md`) are the first user and get ported once this exists.

## Context

Plugins, hooks and tools keep needing the same thing: look up a value by key, with sensible defaults, overridable per machine, per user and per file, and sometimes written back. Today each one rolls its own: an awk parser in `settings.sh`, a regex in `register.ts`, `SKOGAI_*` env switches in `git-steps.sh`, and `scripts/parse-frontmatter.sh` at the repo root.

One CLI, `skogai-config`, replaces all of them. The model is `git config`: ordered layers, last one wins, and `--show-origin` says which file set a value. The storage is YAML frontmatter in markdown files, so every layer can carry notes in its body. Skills, agents, commands and memory files already use the same format.

## Model

A **layer** is the frontmatter of one markdown file, or the environment. A **lookup** reads the layers from lowest to highest priority and deep-merges them. The value is whatever the merged tree holds at the key.

```
1  /etc/skogai/config.md                      system defaults
2  $XDG_CONFIG_HOME/skogai/config.md          user (~/.config/skogai/config.md)
3  $SKOGAI_CONFIG                             one explicit file, if set
4  <file>.md            ┐  only with --file   the file the caller is about
5  <file>.local.md      ┘                     its overlay, gitignored
6  SKOGAI_<KEY>                               environment, last word
```

- **There is no "project layer".** A project, a plugin or a document is just a file someone passes with `--file`. Every `--file X.md` brings its `X.local.md` overlay with it, the way `CLAUDE.md` has `CLAUDE.local.md`. If a project-wide file turns out to be needed, it's one more `--file`, not a new concept.
- **`--file` can repeat.** Each one adds its pair on top of the previous one, in order.
- **Missing files are skipped.** Every layer is optional, and no files at all is a valid config.

### Keys

- Keys are dot paths into the merged tree: `skogai-core.events`, `skogai-core.git.stage_on.stop`.
- Layers 1–3 and 6 are shared by everything, so their keys are namespaced: the top-level key is the plugin or tool name.
- A `--file` layer is usually about one thing, so `--scope NAME` mounts it under `NAME`. With `--scope skogai-core`, `events: [...]` in that file is `skogai-core.events`. Without `--scope`, a file is read from the root.
- Env (layer 6): `SKOGAI_` plus the key uppercased, with `.` and `-` turned into `_`. So `SKOGAI_SKOGAI_CORE_EVENTS` sets `skogai-core.events`. The value is parsed as a YAML scalar or flow list (`true`, `3`, `[a, b]`). The doubled prefix is ugly; see open questions.

### Merging

- Maps deep-merge: `{m: {p: 1}}` under `{m: {q: 2}}` gives `{m: {p: 1, q: 2}}`.
- Scalars and lists replace what's below them. No list appending across layers.
- Setting a key to `null` (`~`) in a higher layer removes it, so a lookup falls through to the caller's default.

### Config vs state

- **Config** is what people edit. Tools read it and never write it unless told to (`set`).
- **State** is what tools write: last event, counters, timestamps. It uses the same format and the same CLI, but lives in its own files (`<file>.state.md`, or `$XDG_STATE_HOME/skogai/<scope>.md`) and is never part of the config stack. A hook rewriting state can then never clobber an edit someone is making to config.

## CLI

```
skogai-config get <key>            print the merged value
skogai-config list                 print the merged tree
skogai-config set <key> <value>    write one layer (see below)
skogai-config unset <key>          remove a key from one layer
skogai-config edit                 open the target layer in $EDITOR

options:
  --file F.md       add F.md and F.local.md as layers (repeatable)
  --scope NAME      mount --file layers under NAME
  --layer L         system | user | env-file | file | local: read or write only that layer
  --show-origin     print the file (or env var) that set each value
  --json | --raw    output: JSON (default for maps and lists) or bare scalar
  --default V       print V instead of failing when the key is missing
```

- **Exit codes,** as in `git config`: 0 found, 1 key missing, 2 usage or parse error. A script can write `skogai-config get k || echo fallback`.
- **Lists** print one item per line with `--raw`, so `for x in $(...)` works in bash.
- **Writes** go to the most specific file layer: `F.local.md` when `--file` is given, otherwise the user layer. `--layer` picks another. Writing never touches a committed `F.md` unless `--layer file` says so.
- **A missing file is created** on write, as `---\n<key>: <value>\n---\n`.

## Implementation

- Bash plus `yq` (mikefarah v4) and `jq`. Shipped as `plugins/skogai-core/bin/skogai-config`. Claude Code puts a plugin's `bin/` on the Bash tool's `PATH` while the plugin is enabled (`docs/plugins/components.md`). For your own shell, symlink it into `~/.local/bin`.
- **Read:** for each layer, `yq --front-matter=extract 'select(document_index == 0)' F`, then merge them all with `yq ea '. as $i ireduce ({}; . * $i)'`. The `document_index == 0` matters: a body containing `---` lines otherwise reads as more YAML documents, and the merge fails.
- **Write:** `yq -i --front-matter=process '.k = v' F`. Checked with yq 4.54.1: it keeps comments, the body and `---` lines in the body.
- **Concurrency:** writes take `flock` on the target file, like `append-json.sh` does for the log. State writes happen from hooks running in parallel.
- **Mods:** `register.ts` calls it with `$.process.run`. Whether a plugin's `bin/` is on `$.process.run`'s `PATH` is untested; if not, pass an absolute path built from the plugin root.
- **Speed:** each hook pays a few `yq` starts. If that shows up, add one call that dumps a whole scope as JSON, and let callers `jq` it.

## Migration

1. Build `bin/skogai-config` with `get`, `list` and `--show-origin`, plus tests in `tests/run.sh`.
2. Port `settings.sh` to call it with `--file <root>/.claude/skogai-core.md --scope skogai-core`, and do the same for `register.ts`, dropping its TypeScript parser. The existing `.claude/skogai-core.local.md` keeps working as that file's overlay.
3. Move the `SKOGAI_{STAGE,COMMIT,MERGE}_ON_*` switches to keys under `skogai-core.git`. Keep reading the old env names for one version.
4. Add `set`, `unset` and the state files. Move anything hooks remember into state.
5. Replace `validate-settings.sh` with a per-scope check (see open questions), and delete `scripts/parse-frontmatter.sh` and `todo/PLUGIN-SETTINGS.md`'s reference to it.

## Left out on purpose

- A project layer. See the Model section.
- Includes (one layer pulling in another file), remote config, encryption.
- List appending across layers. Replacing a list is predictable; appending can't be undone by a higher layer.
- Writing comments. `set` keeps existing comments but adds none.

## Open questions

- **Env naming.** `SKOGAI_SKOGAI_CORE_EVENTS` is clumsy. Options: drop the prefix for the `skogai-` scopes (`SKOGAI_CORE_EVENTS`), or use `SKOGAI_CONFIG_<KEY>`.
- **Schemas.** A per-scope schema (keys, types, defaults) would let one `skogai-config check --scope X` replace every plugin's own validator, and supply defaults so callers stop hard-coding them. It could live in the plugin, such as `plugins/<name>/config.md`, acting as a layer 0 of defaults.
- **Is `/etc/skogai/` worth reading** on a single-user machine, or is the user layer enough to start?
- **Where state lives.** Next to the file (`F.state.md`, visible, easy to delete) or under `$XDG_STATE_HOME` (out of the tree)?
