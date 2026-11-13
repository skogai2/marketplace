# skogai-core

A Claude Code plugin for acting upon hook events. Each event we act upon has its own script, every action is logged, and the status line shows the event being acted upon. What it does and why is in [FEATURES.md](FEATURES.md):

- **Event log:** one JSON row per event we act upon in `.skogai/logs/skogai-core/log.jsonl` at the git root.
- **Diff as handover:** on `Stop`, appends the turn (prompt, reply, tool uses) to `.skogai/journal.md` at the git root and commits only that file (other work and the log are left alone). Optional git steps run `git add -A`, `wt step commit` and `wt merge`.
- **Status line:** shows `hook: <event>` from the log's last row.

All of it is off until switched on in the [settings](#settings).

## Installing it

```sh
/plugin install skogai-core --marketplace skogai2/marketplace
```

## Running it

```sh
cd ~/marketplace
claude --plugin-dir plugins/skogai-core
```

The scripts need `bash`, `jq`, `git` and `flock`. Check the plugin without a session:

```sh
claude plugin validate plugins/skogai-core
```

Test the scripts without a session (needs nothing but the tools above):

```sh
plugins/skogai-core/tests/run.sh
```

Tail the log while you use Claude:

```sh
tail -f .skogai/logs/skogai-core/log.jsonl | jq -c '{event, action}'
```

## Settings

Mod settings (`userConfig` in `.claude-plugin/plugin.json`). Set them with `/plugin configure skogai-core@skogai-marketplace` or in `/config`; they're stored under `pluginConfigs` in `~/.claude/settings.json`, so they apply to every project. Hooks read them from `CLAUDE_PLUGIN_OPTION_<KEY>` (through `scripts/settings.sh`), the status-line module from `options`. Run `/reload-plugins` after a change.

| Key | Default | What it does |
|---|---|---|
| `enabled` | `false` | Master switch. Off: nothing is logged, journaled, written or run |
| `events` | `*` | Hook events to log, space-separated; globs such as `Post*` work. The journal needs `UserPromptSubmit` and `PostToolUse*` |
| `log_path` | `.skogai/logs/skogai-core/log.jsonl` | Event log, relative to the git root or absolute |
| `journal` | `false` | On `Stop`, append the turn to the journal and commit only that file |
| `journal_path` | `.skogai/journal.md` | Turn journal, relative to the git root or absolute |
| `write_state` | `false` | Write `git-diff`, `git-diff-cached` and `wt-step-diff` on `SessionStart`, `UserPromptSubmit` and `Stop` |
| `state_dir` | `.skogai/tmp` | Where the state files go |
| `status_line` | `false` | Show `hook: <event>` from the log's last row |
| `stage_on_stop` / `stage_on_prompt` | `false` | `git add -A` at turn end / on prompt submit |
| `commit_on_stop` / `commit_on_prompt` | `false` | `wt step commit`, skipped when the tree is clean |
| `merge_on_stop` / `merge_on_prompt` | `false` | `wt merge --no-remove` |

Loaded with `--plugin-dir`, the plugin has no configure dialog; set the values under `pluginConfigs["skogai-core@inline"].options` in `~/.claude/settings.json`.

## Files

```
.claude-plugin/plugin.json   manifest
hooks/hooks.json             the events we act upon, plus the status-line module
hooks/register.ts            the status-line mod: shows the log's last event
scripts/events/<Event>.sh    one script per event, run with the event's JSON on stdin
scripts/append-json.sh       appends one row to the log: <json> | append-json.sh [action]
scripts/git-steps.sh         runs the switched-on git steps: git-steps.sh <stop|prompt> <root> [path...]
scripts/write-state.sh       writes git-diff, git-diff-cached, wt-step-diff: write-state.sh <root> <dir>
scripts/settings.sh          sourced by the scripts: reads the mod settings
tests/run.sh                 tests the scripts in a throwaway git repo
```

## Acting upon another event

1. Add the event to `hooks/hooks.json`, pointing at `scripts/events/<Event>.sh`. The events are listed in the [hooks reference](https://code.claude.com/docs/en/hooks#hook-events).
2. Write the script. Do the work, then pipe the input to `append-json.sh` with a short description of what you did. A script that only logs is one line:

   ```sh
   exec "$(dirname "$0")/../append-json.sh"
   ```

A script can also answer back the way any command hook can, with exit code 2 or JSON on stdout.

## Config

[CONFIG.md](CONFIG.md) is the earlier design for reading settings through dash's `skogai config`. It is not wired in; the mod settings above replaced it.

## Learnings

See [LEARNINGS.md](LEARNINGS.md).
