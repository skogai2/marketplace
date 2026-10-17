import type { Register } from 'claude-code'

// The plain hooks in hooks.json do the acting, and each one writes a row to
// the log with scripts/append-json.sh. This module only shows the event of
// the log's last row in the status line.
const LOG = '.skogai/logs/skogai-core/log.jsonl'
// Per-project settings, read the same way as scripts/settings.sh.
const SETTINGS = '.claude/skogai-core.local.md'

// The git root, found once per load. The scripts resolve the log against it
// too, so both agree wherever the session's working directory is.
let root: string | null = null

// One scalar from `skogai config list` output, for a skogai-core key.
function resolved(list: string, key: string): string | undefined {
  const prefix = `skogai-core.${key}=`
  const line = list.split('\n').find(l => l.startsWith(prefix))
  return line === undefined ? undefined : line.slice(prefix.length)
}

// One scalar from the settings file's frontmatter, unquoted, or undefined.
// `log-path` also matches `log_path`.
function setting(text: string, key: string): string | undefined {
  const lines = text.split('\n')
  if (lines[0] !== '---') return undefined
  for (const line of lines.slice(1)) {
    if (line === '---') return undefined
    if (line.startsWith(key + ':') || line.startsWith(key.replace(/-/g, '_') + ':')) {
      return line.slice(key.length + 1).replace(/\s+#.*$/, '').trim().replace(/^(["'])(.*)\1$/, '$2')
    }
  }
  return undefined
}

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
      // Read on every event, so edits to the settings apply without a reload.
      // dash's `skogai config` folds every layer, the settings file among
      // them; without one that knows --file, read the file alone.
      const path = `${root}/${SETTINGS}`
      const config = await $.process.run(['skogai', 'config', 'list', '--file', path.replace(/\.local\.md$/, '.md'), '--scope', 'skogai-core']).catch(() => null)
      let get: (key: string) => string | undefined
      if (config !== null && config.exitCode === 0) {
        get = key => resolved(config.stdout, key)
      } else {
        const text = (await $.fs.exists(path)) ? await $.fs.read(path) : ''
        get = key => setting(text, key)
      }
      if (get('enabled') === 'false' || get('status-line') === 'false') return result
      // tail reads only the last row, so the log can grow past $.fs.read's 4 MiB.
      const last = await $.process.run(['tail', '-n1', `${root}/${get('log-path') || LOG}`])
      const event = JSON.parse(last.stdout).event
      if (typeof event === 'string') $.ui.status('hook: ' + event)
    } catch {}
    return result
  })
}
