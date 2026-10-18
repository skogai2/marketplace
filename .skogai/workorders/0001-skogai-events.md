---
type: workorder
title: skogai-events — event as a dash type, the plugin as its implementation
description: Define `event` in dash-skogai, then rebuild skogai-core as skogai-events, an implementation pinned to a dash commit plus local patches, run with argc + mise.
status: open
created: 2026-10-17
repos:
  - skogai2/skogai (dash-skogai/, ~/skogai/dash-skogai)
  - skogai2/marketplace (plugins/skogai-core)
sources:
  - id: config
    resource: plugins/skogai-core/CONFIG.md
    title: CONFIG.md — layered skogai config (steps 1–4 built)
  - id: dash-type
    resource: https://github.com/skogai2/skogai/blob/master/dash-skogai/type/type.md
    title: dash type — fields, owns, writes, watches
  - id: dash-trigger
    resource: https://github.com/skogai2/skogai/blob/master/dash-skogai/type/trigger.md
    title: dash trigger type
  - id: dash-todo
    resource: https://github.com/skogai2/skogai/blob/master/dash-skogai/TODO.md
    title: dash TODO
---

# skogai-events

## End state

- dash-skogai defines the `event` type: the interface, the defaults and the rules. A repo that wants events follows that blueprint; a repo that doesn't need events has none.
- `plugins/skogai-events` (today `plugins/skogai-core`) is one implementation of it. Its event definitions are dash's, copied in and pinned to a dash commit. Any local change is a patch against them, kept append-only and applied with `git apply`.
- `hooks/hooks.json` is generated from the event definitions, never hand-edited.
- Every script is an argc command run through mise. jq, yq and argc come from mise.
- The name `core` is free again for the bigger concept.

## Decided (skogix, 2026-10-17)

1. **dash is the interface, `.skogai` is the implementation.** dash defines the defaults and rules: the entrypoints, what they return, and the starting watch list. If the defaults work, a repo copies them, pastes them and pins them to a dash commit. If a repo needs to differ, the difference is a diff against dash (`git apply`, immutable, append-only), so a repo's `.skogai` state is close to "dash at a commit, plus patches". Something like moving where the event scripts live is done by patching the files, or with an env var or setting where dash offers one.
2. **Each event is a `type: event` instance with its own JSON schema.** Every event is already a JSON row appended to a jsonl, an immutable linked list. The schema describes that row's `input`.
3. **Rename to skogai-events.** `core` is a bigger concept; `events` is what the plugin literally does.
4. **argc + mise** for the tooling.
5. **Ownership is one step.** `type` owns `type/event.md` and `type/event.schema.json`; `event` owns its instances, `type/event/<name>.md`, `<name>.schema.json` and `scripts/event/<name>.sh`.
6. **Opt-in.** Every event ships off. A repo turns one on with `enabled: true`; a missing event file is off.
7. **Pinned files mirror dash.** The plugin keeps its copy at `type/event/`, the same paths as dash, so dash diffs apply as they are.
8. **Logs and tmp are throwaway.** `.skogai/logs/` and `.skogai/tmp/` are never kept across a change: the rename drops the old log, and the new one is `.skogai/logs/event.jsonl`, without a plugin name.

## What exists now

### dash (skogai2/skogai, `dash-skogai/`)

- `type/type.md` and `type/type.schema.json`: a type is `type: type` with `title`, `fields`, `owns`, `writes`, `watches`. A type's instances live in `type/<name>/`. Every file has exactly one owner.
- `type/trigger.md`: "a script that runs when a file changes or an event happens". Its TODO says to split `when` into a defined `event` field and asks "what is an event, and where does it come from?". This workorder answers that.
- `type/config.md` and `bin/skogai config`: layered git-config, with `--file x.md` frontmatter layers. skogai-core already reads its settings and git steps through it (see [CONFIG.md](../../plugins/skogai-core/CONFIG.md), steps 1–4).
- `workflows/skogai.md`: `check` is written (`mise run dash:check [dot]`); `plan` and `apply` are not.
- Open in dash's TODO, and needed here: where a dot records its dash ref; the owner conflict between `type/<name>/` and `type/<parent>/<name>.md`; how a type declares a derived file.

### The plugin (skogai2/marketplace, `plugins/skogai-core`, 0.7.0)

- **Hooks:** 13 hook events, each with its own script in `scripts/events/<Event>.sh`, all listed by hand in `hooks/hooks.json`. Ten only log. Three do more:
  - `SessionStart` writes the diffs to `.skogai/tmp/`.
  - `UserPromptSubmit` runs the git steps, then writes the diffs.
  - `Stop` writes the journal entry to `.skogai/journal.md`, runs the git steps, then writes the diffs.
- **The row:** `append-json.sh` appends one row per event to `.skogai/logs/skogai-core/log.jsonl`, under `flock`: `{ts, event, action?, input}`. Other features depend on these `input` fields: `prompt_id`, `agent_id`, `prompt`, `tool_name`, `tool_input`, `last_assistant_message` (see `.skogai/features/event-log.md`).
- **Settings:** `.claude/skogai-core.md` / `.local.md` with keys `enabled`, `events`, `log-path`, `status-line`, scoped as `skogai-core.*`. The git steps use unscoped keys (`stage.on-stop`, ...). Reading them goes through `settings.sh`, `register.ts` and `validate-settings.sh`.
- **Status line:** `hooks/register.ts` shows the last row's event.
- **Tests:** `tests/run.sh` runs 9 tests, all passing.

## Work

### A. dash-skogai: define `event`

- [x] **A1. `type/event.md`**: `type: type`, `title: event`. It states:
  - **fields** every instance has: `type`, `title`, and the schema it points at.
  - **owns**: `type/event/<name>.md`, `type/event/<name>.schema.json`, `scripts/event/<name>.sh`.
  - **writes**: the event log.
  - **watches**: none at type level; an instance adds its own.
  - **entrypoint**: `scripts/event/<name>.sh` gets the hook's JSON on stdin. It may answer the way any command hook does: exit 0, exit 2, or JSON on stdout. It appends exactly one row.
  - **defaults**: the log path (`.skogai/logs/event.jsonl`) and the starting watch list. No event is on by default (decision 6). Their keys go in dash's base `config`.
- [x] **A2. The row schema**: `type/event.schema.json` validates event instances; the row `{ts, event, action?, input}` is its `$defs/row`, which each `<name>.schema.json` narrows.
- [x] **A3. One instance per hook event**: `type/event/<name>.md` and `<name>.schema.json` for each of the 13, lowercase (`stop.md`, `title: Stop`). Write each schema's `input` from the hooks reference (`docs/hooks.md` in marketplace). Mark the fields other events depend on as required, such as `prompt_id` and `agent_id` for `Stop`.
- [ ] **A4. `trigger.when`**: names an `event` instance. Paths stay with `watches`.
- [ ] **A5.** List `event` in `type/index.md`; `mise run dash:check` reports `errors=0`.

### B. marketplace: skogai-core → skogai-events

- [ ] **B1. Rename** `plugins/skogai-core` → `plugins/skogai-events`:
  - `plugin.json` gets the new `name` and a minor version bump.
  - `.claude-plugin/marketplace-header.json` gets `"renames": {"skogai-core": "skogai-events"}`; then rerun `scripts/generate-marketplace-json.sh`.
  - The config scope `skogai-core.*` becomes `skogai-events.*`, so the env prefix `SKOGAI_SKOGAICORE_*` becomes `SKOGAI_SKOGAIEVENTS_*`.
  - The settings file becomes `.claude/skogai-events.md`.
  - The log moves to `.skogai/logs/event.jsonl`; the old `.skogai/logs/skogai-core/` is deleted (decision 8).
- [ ] **B2. Pin:** copy dash's `type/event/` into the plugin at a dash commit, and record that commit (see questions).
- [ ] **B3. Patches:** local changes live in append-only `*.diff` files. Applying them in order to the pinned copy gives the working files. A check fails if the working files differ from "pin + patches".
- [ ] **B4. Generate `hooks/hooks.json`** from the event instances that are on, with a script next to `generate-marketplace-json.sh`. `register.ts` stays in `modules`.
- [ ] **B5. argc + mise:**
  - `scripts/events/<Event>.sh` becomes `scripts/event/<name>.sh`, as argc commands with `@describe` and `@meta require-tools`.
  - The plugin ships a `mise.toml` with argc, jq and yq.
  - Hooks run through `mise -C "${CLAUDE_PLUGIN_ROOT}" x -- ...`.
  - A hook must not block a prompt when mise or a tool is missing: it exits 0 and writes to stderr.
- [ ] **B6. Settings:** the event-file frontmatter replaces `events` (`enabled: true` per event, off otherwise). It is read as one more `--file` layer of `skogai config`. Remove whatever has no reader left; keep the fallback for a machine without `skogai`, per CONFIG.md step 4.
- [ ] **B7. Verify:**
  - `tests/run.sh` updated and green;
  - `claude plugin validate plugins/skogai-events`;
  - `claude -p "reply with just OK" --plugin-dir plugins/skogai-events`;
  - one real session whose journal entry and log rows match the schemas.
- [ ] **B8. Docs:** README, FEATURES, `.skogai/features/*`, CONFIG.md and LEARNINGS describe the result; nothing points at a path that's gone.

## Open questions

Each one says which step it blocks.

1. **Dash ref (blocks B2):** where does a dot record the commit it pins? dash's TODO suggests `dash.ref` in the local config.
2. **This file's type:** no workorder type exists yet. dash has a stub `task` and a TODO to rename it to `workorder`. This file uses `type: workorder` and `status: open|done|blocked`, per the glossary.

## Out of scope

- `mise install` fails for worktrunk, because upstream returns 404 for its skill files.
- Defining `core`.

## Done when

- dash `check` is clean, with `event` and 13 instances.
- skogai-events loads and passes validation, and its event files equal "dash at the pinned commit + patches".
- `hooks.json` is generated.
- With those 3 enabled, the acting events behave as they did in skogai-core 0.7.0.
