# hook-tap

A function-hooks mod for Claude Code, built to learn how hooks fire. It does two things:

- **Status line:** shows `hook: <stage>` for the last event it saw.
- **Log:** appends one JSON line per event to `plugins/hook-tap/log.jsonl`, relative to the session's working directory:

  ```json
  {"ts":"2026-10-04T18:00:00.000Z","stage":"tool.call","event":{...the event's input...}}
  ```

## Running it

Start Claude from the repo root so the log path resolves:

```sh
cd ~/skogai-fleet
claude --plugin-dir ~/skogai-fleet/plugins/hook-tap
```

An interactive session watches a `--plugin-dir` folder, so saving `hooks/register.ts` reloads the mod. Watch the transcript for dim reload lines, or run with `claude --debug` to see skipped hooks and load errors.

Check the mod at any time, without a session:

```sh
claude plugin validate plugins/hook-tap
```

Tail the log while you use Claude:

```sh
tail -f plugins/hook-tap/log.jsonl | jq -c '{stage, event}'
```

## Files

```
.claude-plugin/plugin.json   manifest
hooks/hooks.json             {"modules": ["./register.ts"]}
hooks/register.ts            the module: one on() per event
```

## What is logged

`session.start`, `session.end`, `turn.start`, `turn.complete`, `prompt.submit`, `prompt.compose`, `command.run`, `tool.call`, `tool.check`, `session.compact`.

Left out on purpose:

- `turn.step` and `process.spawn` are streams. Subscribing to them needs an async generator hook, not a plain one.
- `telemetry.*` is high volume and only useful for telemetry work.
- `ui.render` fires on every redraw and would bury everything else.

To log more, add an `on('<event>', ...)` block. Add it by name: the validator rejects anything else.

## Learnings

See [LEARNINGS.md](LEARNINGS.md).
