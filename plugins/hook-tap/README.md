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

Every event `claude plugin validate` can register a plain hook for, grouped as the [reference](https://code.claude.com/docs/en/plugins/mods/reference#events) groups them:

- **Session:** `session.start`, `session.end`, `session.compact`, `session.receive`, `session.send`, `session.append`, `session.attach`, `session.detach`, `session.measure`
- **Turns:** `turn.start`, `turn.complete`
- **Prompts:** `prompt.submit`, `prompt.compose`, `prompt.section`, `prompt.context`, `prompt.attachment`, `prompt.mention`, `skill.prompt`, `attribution.text`
- **Commands and configuration:** `command.run`, `command.describe`, `config.set`, `config.describe`
- **Tools:** `tool.call`, `tool.check`, `tool.describe`
- **Subagents:** `agent.offer`, `agent.spawn`
- **Interface:** `ui.resolve`, `ui.press`, `ui.input`, `ui.select`, `ui.focus`, `ui.scroll`, `ui.close`, `ui.message`, `ui.fault`
- **Other mods:** `plugin.register`
- **Settings hooks:** `classic.*`, a wildcard that matches every settings-hook event (`Stop`, `PreToolUse`, `SessionStart`, ...) in one handler. `e` carries the same stdin JSON a settings hook would read, including `hook_event_name`, so the logged line still says which one fired.

Left out on purpose:

- `turn.step` and `process.spawn` are streams. Subscribing to them needs an async generator hook, not a plain one.
- `telemetry.log` and `telemetry.mark` are high volume, and a mod we install must filter them with `{ to: 'collector' }` or the validator rejects the module.
- `ui.render` fires on every redraw and would bury everything else.
- `prompt.edit`, `prompt.fill`, and `prompt.suggest` fire on the keystroke path (the prompt box as the user types), so they'd flood the log the same way `ui.render` would.
- `engine.create` fires while `$` itself is still being built for this mod, so `$.ui.status` and `$.fs` aren't there yet. A hook on it threw `undefined is not an object` — see [LEARNINGS.md](LEARNINGS.md).

To log more, add an `on('<event>', ...)` block. Add it by name: the validator rejects anything else.

## Learnings

See [LEARNINGS.md](LEARNINGS.md).
