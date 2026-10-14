import type { Register } from 'claude-code'

// The plain hooks in hooks.json do the acting, and each one writes a row to
// the log with scripts/append-json.sh. This module only shows the event of
// the log's last row in the status line.
const LOG = '.skogai/logs/hook-tap/log.jsonl'

// The git root, found once per load. The scripts resolve the log against it
// too, so both agree wherever the session's working directory is.
let root: string | null = null

export const register: Register = on => {
  // classic.* matches every settings hook event (Stop, PreToolUse, ...).
  on('classic.*', async ($, e, next) => {
    // Let the plain hooks run, and write their row, before reading the log.
    const result = await next(e)
    try {
      if (root === null) {
        const git = await $.process.run(['git', 'rev-parse', '--show-toplevel'])
        root = git.exitCode === 0 ? git.stdout.trim() : '.'
      }
      // tail reads only the last row, so the log can grow past $.fs.read's 4 MiB.
      const last = await $.process.run(['tail', '-n1', `${root}/${LOG}`])
      const event = JSON.parse(last.stdout).event
      if (typeof event === 'string') $.ui.status('hook: ' + event)
    } catch {}
    return result
  })
}
