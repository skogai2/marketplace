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

// Left out on purpose:
//   - turn.step and process.spawn are streams: a plain async hook isn't what
//     the engine expects there, they need an async generator.
//   - telemetry.log and telemetry.mark are high volume, and a mod we install
//     must filter them with { to: 'collector' } or claude plugin validate
//     rejects the module.
//   - ui.render fires on every redraw and would bury everything else.
//   - prompt.edit, prompt.fill, and prompt.suggest fire on the keystroke
//     path (the prompt box as the user types), so they'd flood the log the
//     same way ui.render would.
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

  on('session.compact', async ($, e, next) => {
    $.ui.status('hook: session.compact')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.compact', e) + '\n')
    })
    return next(e)
  })

  on('session.receive', async ($, e, next) => {
    $.ui.status('hook: session.receive')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.receive', e) + '\n')
    })
    return next(e)
  })

  on('session.send', async ($, e, next) => {
    $.ui.status('hook: session.send')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.send', e) + '\n')
    })
    return next(e)
  })

  on('session.append', async ($, e, next) => {
    $.ui.status('hook: session.append')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.append', e) + '\n')
    })
    return next(e)
  })

  on('session.attach', async ($, e, next) => {
    $.ui.status('hook: session.attach')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.attach', e) + '\n')
    })
    return next(e)
  })

  on('session.detach', async ($, e, next) => {
    $.ui.status('hook: session.detach')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.detach', e) + '\n')
    })
    return next(e)
  })

  on('session.measure', async ($, e, next) => {
    $.ui.status('hook: session.measure')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('session.measure', e) + '\n')
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

  on('prompt.section', async ($, e, next) => {
    $.ui.status('hook: prompt.section')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.section', e) + '\n')
    })
    return next(e)
  })

  on('prompt.context', async ($, e, next) => {
    $.ui.status('hook: prompt.context')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.context', e) + '\n')
    })
    return next(e)
  })

  on('prompt.attachment', async ($, e, next) => {
    $.ui.status('hook: prompt.attachment')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.attachment', e) + '\n')
    })
    return next(e)
  })

  on('prompt.mention', async ($, e, next) => {
    $.ui.status('hook: prompt.mention')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('prompt.mention', e) + '\n')
    })
    return next(e)
  })

  on('skill.prompt', async ($, e, next) => {
    $.ui.status('hook: skill.prompt')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('skill.prompt', e) + '\n')
    })
    return next(e)
  })

  on('attribution.text', async ($, e, next) => {
    $.ui.status('hook: attribution.text')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('attribution.text', e) + '\n')
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

  on('command.describe', async ($, e, next) => {
    $.ui.status('hook: command.describe')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('command.describe', e) + '\n')
    })
    return next(e)
  })

  on('config.set', async ($, e, next) => {
    $.ui.status('hook: config.set')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('config.set', e) + '\n')
    })
    return next(e)
  })

  on('config.describe', async ($, e, next) => {
    $.ui.status('hook: config.describe')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('config.describe', e) + '\n')
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

  on('tool.describe', async ($, e, next) => {
    $.ui.status('hook: tool.describe')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('tool.describe', e) + '\n')
    })
    return next(e)
  })

  on('agent.offer', async ($, e, next) => {
    $.ui.status('hook: agent.offer')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('agent.offer', e) + '\n')
    })
    return next(e)
  })

  on('agent.spawn', async ($, e, next) => {
    $.ui.status('hook: agent.spawn')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('agent.spawn', e) + '\n')
    })
    return next(e)
  })

  on('ui.resolve', async ($, e, next) => {
    $.ui.status('hook: ui.resolve')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.resolve', e) + '\n')
    })
    return next(e)
  })

  on('ui.press', async ($, e, next) => {
    $.ui.status('hook: ui.press')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.press', e) + '\n')
    })
    return next(e)
  })

  on('ui.input', async ($, e, next) => {
    $.ui.status('hook: ui.input')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.input', e) + '\n')
    })
    return next(e)
  })

  on('ui.select', async ($, e, next) => {
    $.ui.status('hook: ui.select')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.select', e) + '\n')
    })
    return next(e)
  })

  on('ui.focus', async ($, e, next) => {
    $.ui.status('hook: ui.focus')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.focus', e) + '\n')
    })
    return next(e)
  })

  on('ui.scroll', async ($, e, next) => {
    $.ui.status('hook: ui.scroll')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.scroll', e) + '\n')
    })
    return next(e)
  })

  on('ui.close', async ($, e, next) => {
    $.ui.status('hook: ui.close')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.close', e) + '\n')
    })
    return next(e)
  })

  on('ui.message', async ($, e, next) => {
    $.ui.status('hook: ui.message')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.message', e) + '\n')
    })
    return next(e)
  })

  on('ui.fault', async ($, e, next) => {
    $.ui.status('hook: ui.fault')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('ui.fault', e) + '\n')
    })
    return next(e)
  })

  on('plugin.register', async ($, e, next) => {
    $.ui.status('hook: plugin.register')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('plugin.register', e) + '\n')
    })
    return next(e)
  })

  // engine.create is left out: it fires while $ itself is still being built
  // for this mod, so $.ui.status and $.fs are not there yet. A hook on it
  // threw `undefined is not an object` until this was found by testing.

  // One handler for every settings hook event (Stop, PreToolUse, SessionStart,
  // ...): classic.* is a wildcard the engine matches by name, not a literal
  // event. e carries the same stdin JSON a settings hook would read, including
  // hook_event_name, so a single line still says which one fired.
  on('classic.*', async ($, e, next) => {
    $.ui.status('hook: classic.*')
    await enqueue(async () => {
      const previous = (await $.fs.exists(LOG)) ? await $.fs.read(LOG) : ''
      await $.fs.write(LOG, previous + lineFor('classic.*', e) + '\n')
    })
    return next(e)
  })
}
