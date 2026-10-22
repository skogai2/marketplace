---
type: module
name: memory
description: one fact per file, each with a stale_after; expired ones get decided on
command: argc.sh
tools: [yq]
requires: [core]
files:
  - templates/
config:
  dir: memory
  index: MEMORY.md
  stale-days: 30
---

# memory

local memory (decision 0007): anything, written freely, maintained. each entry
is `<dir>/<name>.md` with `name`, `description`, `created` and `stale_after`
in its frontmatter (or under `metadata:`, as Claude Code writes them), and one line in `<dir>/<index>`. on expiry an entry
becomes knowledge, state, an action, or is forgotten: `skogai memory stale`
lists what is due.

| key | default | what |
|---|---|---|
| `memory.dir` | `memory` | the entries, relative to `.skogai/` |
| `memory.index` | `MEMORY.md` | the index, inside `memory.dir` |
| `memory.stale-days` | `30` | days from `created` to `stale_after` for `new` |

`templates/entry.md` is what `new` writes; an installed copy can be edited.
