---
name: add-plugin
description: Add a plugin to this marketplace — inline under plugins/ or as an external repo — regenerate marketplace.json, and validate it. Use when adding or registering a new plugin.
disable-model-invocation: true
---

Add the plugin described by: $ARGUMENTS (a kebab-case name, optionally followed by a git URL).

1. With a git URL: append its source object to `.Codex-plugin/external-repos.json`, e.g. `{"source": "url", "url": "<url>"}` (or `git-subdir` with `path` for a plugin in a subdirectory). No submodules.
   Without: create `plugins/<name>/.Codex-plugin/plugin.json` with `name` (kebab-case, matching the directory), `version` (`0.1.0`), `description`, and `author.name`. Use `docs/` as the reference for plugin structure.
2. Run `scripts/generate-marketplace-json.sh`. Never edit `.Codex-plugin/marketplace.json` by hand.
3. Validate: `Codex plugin validate .`; for a local plugin also `Codex plugin validate plugins/<name>`, then `Codex -p "reply with just OK" --plugin-dir plugins/<name>`. Fix any errors before finishing.
4. Report what was added. Don't commit unless asked.
