# skogai-core

A Claude Code plugin for acting upon hook events. Each event we act upon has its own script, every action is logged, and the status line shows the event being acted upon. What it does and why is in [FEATURES.md](FEATURES.md):

- **Event log:** one JSON row per event we act upon in `.skogai/logs/skogai-core/log.jsonl` at the git root.
- **Diff as handover:** on `Stop`, appends the turn (prompt, reply, tool uses) to `.skogai/journal.md` at the git root. `SKOGAI_{STAGE,COMMIT,MERGE}_ON_{STOP,USER_PROMPT_SUBMIT}` switch on `git add -A`, `wt step commit` and `wt merge`; all are off unless set to `true`.
- **Status line:** shows `hook: <event>` from the log's last row.

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

Per project, in `.claude/skogai-core.local.md` at the git root (gitignored). Start from the example and check it:

```sh
cp plugins/skogai-core/examples/skogai-core.local.md .claude/
plugins/skogai-core/scripts/validate-settings.sh
```

| Key | Default | What it does |
|---|---|---|
| `enabled` | `true` | `false` switches everything off: log, journal, git steps, status line |
| `events` | all | Hook events to log, as a list; globs such as `"Post*"` work. The journal needs `UserPromptSubmit` and `PostToolUse*` |
| `log-path` | `.skogai/logs/skogai-core/log.jsonl` | Where the log goes, relative to the git root |
| `status-line` | `true` | `false` hides `hook: <event>` |

Keys may also be written with `_` (`log_path`). Scripts read the file on every event and so does the status line, so edits apply without a restart.

With dash's `skogai config` on PATH (one that knows `--file`), the file is one layer of it: the same keys can come from `~/.skogai/config` or a repo's `.skogai/config` as `skogai-core.<key>`, or from env as `SKOGAI_SKOGAI_CORE_<KEY>`. `skogai config list --show-origin --file .claude/skogai-core.md --scope skogai-core` shows where each value came from. Without it, only the file is read. The git-step switches stay env vars (see [diff as handover](.skogai/features/diff-as-handover.md)).

## Files

```
.claude-plugin/plugin.json   manifest
hooks/hooks.json             the events we act upon, plus the status-line module
hooks/register.ts            the status-line mod: shows the log's last event
scripts/events/<Event>.sh    one script per event, run with the event's JSON on stdin
scripts/append-json.sh       appends one row to the log: <json> | append-json.sh [action]
scripts/git-steps.sh         runs the switched-on git steps: git-steps.sh <EVENT> <root>
scripts/write-state.sh       writes git-diff, git-diff-cached, wt-step-diff to .skogai/tmp/
scripts/settings.sh          sourced by the scripts: reads .claude/skogai-core.local.md
scripts/validate-settings.sh checks a settings file: validate-settings.sh [path]
examples/skogai-core.local.md  settings to copy into a project
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

Reading settings through dash's `skogai config`, with frontmatter files as extra layers, is proposed in [CONFIG.md](CONFIG.md).

## Learnings

See [LEARNINGS.md](LEARNINGS.md).
