---
type: module
name: config
description: config across system, global, local, module and markdown file layers
command: argc.sh
tools: [git, yq, argc]
requires: []
---

# config

the config half of skogai-runner's core module (`~/.local/src/skogai-runner`), copied out as is.

| command | |
|---|---|
| `get <key> [--show-origin] [--file]... [--scope]` | a resolved value; a list prints one item per line |
| `set <key> <value> [--global\|--module\|--file] [--scope]` | write the local layer, the global one, a module's `module.local.md` or a file's `.local.md` |
| `unset <key> [--global\|--module\|--file] [--scope]` | remove a key from that layer |
| `list [--show-origin] [--file]... [--scope]` | every resolved key as `key=value` |
| `env [--file]... [--scope]` | the resolved config as export lines |
| `files [--file]...` | each layer's path, and whether it exists |

fold order, later wins:

1. `config:` in every found `module.md` (defaults), mounted under the module's name
2. system, global, local: git-config files `config` in `$SKOGAI_SYSTEM_DIR`
   (`/etc/skogai`), `$SKOGAI_CONFIG_DIR` (`~/.config/skogai`), `$SKOGAI_LOCAL_DIR`
   (`.skogai` at the git root)
3. `config:` in each module's `module.local.md`
4. each `--file X.md`'s frontmatter, then its `X.local.md`
5. `SKOGAI_*` env: `stage.on-stop` is `SKOGAI_STAGE_ONSTOP`

frontmatter flattens to dotted keys, `_` reads as `-`; a null removes a key an
earlier layer set. modules are found installed (`<local>/modules`, then
`<global>/modules`), then in `$SKOGAI_MODULE_PATH` (default the dir this module
sits in); the first by a name wins.
