---
type: module
name: marketplace
description: scaffold, validate, eval and improve this marketplace's plugins
command: argc.sh
tools: [jq, git, claude]
requires: [core, runner]
files: []
config: {}
---

# marketplace

local to the skogai-marketplace repo (`.skogai/modules/marketplace/`), so
`skogai marketplace` exists only inside it and works on it.

| recipe | |
|---|---|
| `new <name> <description>` | scaffold `plugins/<name>` with one skill |
| `check [name]...` | `claude plugin validate` each (all if none), then `generate-marketplace-json.sh --check` |
| `json` | regenerate `.claude-plugin/marketplace.json` |
| `evals <name>` | `claude plugin eval` a plugin |
| `improve [--apply] <name> <request>` | `skogai runner improve` over every file of a plugin |
