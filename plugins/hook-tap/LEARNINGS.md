# Learnings: building hook-tap

Notes from the first mod. Each entry records what we found, where it came from, and what it means for the next plugin. Keep appending as we learn more; this is the seed for a larger hooks-and-plugins project.

## Validator rules (`claude plugin validate`)

Verified by running the validator against this mod, build 2.1.289.

- **`on()` takes the event name as a string literal.** A variable (`on(stage, ...)`, looping over a list) fails with "the event name passed to on() is not a string literal". Every event must be written out.
- **The hook must be a function literal.** `on('x', tap('x'))` fails because the hook is a call result. Use `on('x', async ($, e, next) => ...)`.
- **`$` is only used as `$.noun.method(...)`.** Passing `$` to a helper fails. Passing `$.fs` as a value also fails. Calls such as `$.fs.read(...)` inside a closure are fine.
- **Helpers are fine when they don't take `$`.** A module-level queue and a `lineFor(stage, e)` formatter both pass.
- **Good output looks like:** `hooks: <events>` and `calls: $.fs.exists, $.fs.read, $.fs.write, $.ui.status`. The validator lists every event and call it found, which is the quickest way to confirm what a mod does.
- **The `author` warning is harmless.** It appears when `plugin.json` has no author field.

## The file API

From `types/claude-code.d.ts` (`fs` section):

- **No append.** `$.fs.write(path, text)` overwrites the whole file. Appending means read, concatenate, write.
- **Concurrent writes can clobber each other.** Two events firing at once both read the old contents. A module-level promise queue serializes the read-modify-write.
- **4 MiB read limit.** `$.fs.read` rejects over 4 MiB, so once the log grows past that the append fails. The hook swallows the error (`.catch(() => {})`) to avoid breaking the chain, which means logging stops silently. **Open issue:** rotate the log, or write a line per file, before this bites.
- **Paths are relative to the session's working directory,** not the plugin folder. Launch Claude from the repo root, or the log lands somewhere unexpected.

## Hooks and events

- **Pass-through is `return next(e)`.** A hook that returns without `next` answers for the event itself and stops the chain.
- **Streams need a generator.** `turn.step` and `process.spawn` are async generators. A plain `async` hook on them is not what the engine expects, so they are excluded.
- **`ui.render` fires on every redraw.** Logging it floods the file. Filter it, or keep it out.
- **Event names come from the types file.** The input-event list sits in `claude-code.d.ts` as `'<name>': <Name>Input`. Grep it before guessing a name.

## Loading and reloading

- **`--plugin-dir` avoids the enable prompt.** The engine's one-time "Enable hot reloading?" question applies to the dev-mods folder. A `--plugin-dir` folder is watched in an interactive session without it.
- **Reloads reset module variables.** `register` runs again, so the queue starts over. Values in `$.state` and `$.store` survive; plain `let` variables do not.

## Headless check (done)

`claude -p "reply with just OK" --plugin-dir plugins/hook-tap` wrote six lines: `session.start`, `prompt.compose`, `prompt.submit`, `turn.start`, `turn.complete`, `session.end`. The model answered `OK`.

- **Order is what you'd expect:** the session opens, the system prompt is composed, the prompt is submitted, the turn runs, then the session ends.
- **`tool.call` did not fire** because the reply used no tools. A prompt that runs Bash should produce `tool.call` lines.
- **`session.end` carries a `resume` id,** so the log can be joined to the transcript.
- **Headless has no surface.** `surface` is `null` and `isInteractive` is `false`, so the status line can't be seen here. Check it in an interactive session.

## Not done yet

- **Interactive run not yet observed.** The status line and hot reload need a real terminal. Next step: `claude --plugin-dir ~/skogai-fleet/plugins/hook-tap` from the repo root, send a prompt that runs Bash, and check the status line and `log.jsonl`.
- **`claude plugin test`** needs a `*.test.ts` file. Not written yet; the test kit's API is in `reference.md` under "Developing one".
