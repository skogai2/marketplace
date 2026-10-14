---
name: add-plugin
description: Add a plugin to this marketplace — inline under plugins/ or as a git submodule — register it in marketplace.json, and validate it. Use when adding or registering a new plugin.
disable-model-invocation: true
---

Add the plugin described by: $ARGUMENTS (a kebab-case name, optionally followed by a git URL).

1. Directory is `plugins/<name>` (name must be kebab-case and match the directory).
   - With a git URL: `git submodule add <url> plugins/<name>`.
   - Without: create `plugins/<name>/.claude-plugin/plugin.json` with `name`, `version` (`0.1.0`), `description`, and `author.name`. Use `docs/` as the reference for plugin structure.
2. Add an entry to `.claude-plugin/marketplace.json` `plugins` array: `{"name": "<name>", "source": "./<name>", "description": "..."}`. `source` is relative to `pluginRoot` (`./plugins/`) — do not prefix `plugins/`. Keep the array alphabetical.
3. Validate: `claude plugin validate plugins/<name>`, then `claude -p "reply with just OK" --plugin-dir plugins/<name>`. Fix any errors before finishing.
4. Report what was added. Don't commit unless asked.
