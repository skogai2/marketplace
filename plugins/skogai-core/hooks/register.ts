import type { Register } from 'claude-code'

// The plain hooks in hooks.json do the acting, and each one writes a row to
// the log with scripts/append-json.sh. This module only shows the event of
// the log's last row in the status line, when the `enabled` and
// `status_line` mod settings are both on. `options` holds the userConfig
// values from plugin.json, defaults filled in.
const LOG = '.skogai/logs/skogai-core/log.jsonl'

// The git root, found once per load. The scripts resolve the log against it
// too, so both agree wherever the session's working directory is.
let root: string | null = null

// Shows the event of the log's last row in the status line. Errors are
// swallowed: a status line is never worth failing the event over.
async function refresh($: any, logPath: string): Promise<void> {
  try {
    if (root === null) {
      const git = await $.process.run(['git', 'rev-parse', '--show-toplevel'])
      root = git.exitCode === 0 ? git.stdout.trim() : '.'
    }
    const log = logPath.startsWith('/') ? logPath : `${root}/${logPath}`
    // tail reads only the last row, so the log can grow past $.fs.read's 4 MiB.
    const last = await $.process.run(['tail', '-n1', log])
    const event = JSON.parse(last.stdout).event
    if (typeof event === 'string') $.ui.status('hook: ' + event)
  } catch {}
}

export const register: Register = (on, options: any) => {
  const opts = options ?? {}
  // Off by default: register no hooks at all unless both switches are on.
  // After changing a mod setting, run /reload-plugins.
  if (opts.enabled !== true || opts.status_line !== true) return
  const logPath: string = typeof opts.log_path === 'string' && opts.log_path !== '' ? opts.log_path : LOG

  // Not classic.*: the built-in cc-plugin-sec-default guard passes settings
  // hook events past user-installed mods, so a classic.* hook never runs.
  // These native events fire around the same moments. Each passes the event
  // on first, so the plain hooks have written their row before the read.
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($, logPath)
    return result
  })
  on('turn.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($, logPath)
    return result
  })
  on('tool.call', async ($, e, next) => {
    const result = await next(e)
    await refresh($, logPath)
    return result
  })
  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($, logPath)
    return result
  })
}
