# Plan: skogai-core becomes skogai-events

`core` stays the name for the bigger concept. What this plugin does is literally events: each one is a JSON row appended to a jsonl, an immutable linked list. So it becomes `skogai-events`, and `event` becomes a type defined in dash-skogai.

## dash-skogai: the blueprint

dash-skogai defines the `event` type once: the interface, the defaults and the rules. A repo that wants events agrees to follow it. Not every repo needs events.

- `.skogai/knowledge/types/event.md`: the type in plain markdown, with its definition in the frontmatter.
- One JSON schema for the row every event appends: `ts`, `event`, `action`, `input`.
- One definition per event (`Stop`, `PreToolUse`, …), each with its own schema for `input`:

  ```markdown
  ---
  type: event
  title: Stop
  owns: [scripts/events/Stop.sh]
  writes: [.skogai/journal.md, .skogai/logs/skogai-core/log.jsonl]
  watches: [.skogai/logs/skogai-core/log.jsonl]
  schema: Stop.schema.json
  ---
  ```

- Entrypoints and returns: `scripts/events/<title>.sh` reads the hook's JSON on stdin and answers the way any command hook does (exit 0, exit 2, or JSON on stdout). It appends exactly one row.
- The defaults, such as the starting watch list and the paths.

## A repo's .skogai: the implementation

- If the defaults work, copy the definitions in and pin them to a dash-skogai commit.
- Local changes are a diff against dash, kept append-only and applied with `git apply`. To move where the event scripts live, patch the files themselves, or set an env var or setting where the blueprint offers one.
- So a repo's `.skogai` state is, as far as possible, dash-skogai at a commit plus its patches.

## Tooling

jq, yq and argc come from mise (`mise.toml`). The scripts become argc commands, run as mise tasks, so the arguments, help and dependencies are declared in one place. This also replaces the three settings parsers (`settings.sh`, `register.ts`, `validate-settings.sh`) with a yq read of the definition files.

## Order

1. Draft the `event` type and the 13 event definitions from what the scripts do now. They go into dash-skogai, which this repo can't push to.
2. Rename the plugin to `skogai-events`, with `"skogai-core": "skogai-events"` in the marketplace header's `renames`.
3. Generate `hooks/hooks.json` from the definitions, like `marketplace.json` is generated from the `plugin.json` files.
4. Move the scripts to argc + mise, reading their settings from the definitions; then drop `.claude/skogai-core.local.md` and the `SKOGAI_*_ON_*` env vars.
5. Pin and patch: copy, pin to a dash commit, `git apply` local diffs.
