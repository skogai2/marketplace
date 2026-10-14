# hook-tap

A Claude Code plugin for acting upon hook events. Each event we act upon has its own script, every action is logged, and the status line shows the event being acted upon. What it does and why is in [FEATURES.md](FEATURES.md):

- **Event log:** one JSON row per event we act upon in `.skogai/logs/hook-tap/log.jsonl` at the git root.
- **Diff as handover:** on `Stop`, appends the turn (prompt, reply, tool uses) to `.skogai/journal.md` at the git root and runs `git add -A`. Nothing is committed automatically.
- **Status line:** shows `hook: <event>` from the log's last row.

## Running it

```sh
cd ~/marketplace
claude --plugin-dir plugins/hook-tap
```

The scripts need `bash`, `jq`, `git` and `flock`. Check the plugin without a session:

```sh
claude plugin validate plugins/hook-tap
```

Tail the log while you use Claude:

```sh
tail -f .skogai/logs/hook-tap/log.jsonl | jq -c '{event, action}'
```

## Files

```
.claude-plugin/plugin.json   manifest
hooks/hooks.json             the events we act upon, plus the status-line module
hooks/register.ts            the status-line mod: shows the log's last event
scripts/events/<Event>.sh    one script per event, run with the event's JSON on stdin
scripts/append-json.sh       appends one row to the log: <json> | append-json.sh [action]
```

## Acting upon another event

1. Add the event to `hooks/hooks.json`, pointing at `scripts/events/<Event>.sh`. The events are listed in the [hooks reference](https://code.claude.com/docs/en/hooks#hook-events).
2. Write the script. Do the work, then pipe the input to `append-json.sh` with a short description of what you did. A script that only logs is one line:

   ```sh
   exec "$(dirname "$0")/../append-json.sh"
   ```

A script can also answer back the way any command hook can, with exit code 2 or JSON on stdout.

## Learnings

See [LEARNINGS.md](LEARNINGS.md).
