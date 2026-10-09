import type { Register } from 'claude-code'

// Relative to the session's working directory. Run claude from the repo root
// (or change this) so the log lands where you expect.
const LOG = '.skogai/logs/hook-tap/log.jsonl'

// $.fs has no append, so each write reads the file, adds a line, and writes it
// back. Writes are chained so two events cannot overwrite each other.
let queue: Promise<void> = Promise.resolve()

const enqueue = (task: () => Promise<void>) => {
  queue = queue.then(task).catch(() => {})
  return queue
}

const lineFor = (stage: string, e: unknown) =>
  JSON.stringify({ ts: new Date().toISOString(), stage, event: e }) ?? 'null'

// Streams (turn.step, process.spawn, telemetry.*) and ui.render (every frame)
// are left out: they would bury the log in noise.
//
// The validator wants each on() to name its event as a string literal, take a
// function literal, and use $ only as $.noun.method(...), so every event is
// written out below.
export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    $.ui.status('hook: session.start')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.start', e) + '\n')
    })
    return next(e)
  })

  on('session.end', async ($, e, next) => {
    $.ui.status('hook: session.end')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.end', e) + '\n')
    })
    return next(e)
  })

  on('turn.start', async ($, e, next) => {
    $.ui.status('hook: turn.start')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('turn.start', e) + '\n')
    })
    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    $.ui.status('hook: turn.complete')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('turn.complete', e) + '\n')
    })
    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    $.ui.status('hook: prompt.submit')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.submit', e) + '\n')
    })
    return next(e)
  })

  on('prompt.compose', async ($, e, next) => {
    $.ui.status('hook: prompt.compose')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.compose', e) + '\n')
    })
    return next(e)
  })

  on('command.run', async ($, e, next) => {
    $.ui.status('hook: command.run')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('command.run', e) + '\n')
    })
    return next(e)
  })

  on('tool.call', async ($, e, next) => {
    $.ui.status('hook: tool.call')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('tool.call', e) + '\n')
    })
    return next(e)
  })

  on('tool.check', async ($, e, next) => {
    $.ui.status('hook: tool.check')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('tool.check', e) + '\n')
    })
    return next(e)
  })

  on('session.compact', async ($, e, next) => {
    $.ui.status('hook: session.compact')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.compact', e) + '\n')
    })
    return next(e)
  })
}
