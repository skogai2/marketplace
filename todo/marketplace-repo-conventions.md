# skogai-marketplace Conventions

How plugins are laid out in this repository (`skogai-marketplace`), as
distinct from the generic Claude Code plugin spec in SKILL.md. Consult this
file when adding or auditing a plugin here, not when explaining plugin
structure in the abstract.

## Repository Layout

```
.claude-plugin/marketplace.json   the marketplace manifest
plugins/<name>/                   one directory per plugin
scripts/                          generate-marketplace-json.sh, git hooks
todo/                             reference material to review
docs/                             mirrored Claude Code docs (read-only reference)
.skogai/                          local runtime state, gitignored
```

## Marketplace Manifest

`.claude-plugin/marketplace.json` is generated; never edit it by hand. Run:

```sh
bash scripts/generate-marketplace-json.sh
```

It builds the file from three inputs:

- `.claude-plugin/marketplace-header.json`: top-level fields (`name`, `owner`,
  `metadata.pluginRoot`, `renames`, ...). `version` is bumped automatically.
- `plugins/*/.claude-plugin/plugin.json`: local plugins, written as bare-name
  sources (`"source": "skogai-core"`), resolved under `pluginRoot` (`./plugins/`).
- `.claude-plugin/external-repos.json`: plugins in other repos, as an array of
  plugin source objects copied verbatim into `marketplace.json`.

Each entry carries only `name`, `source` and `description`, read from the
plugin's own `plugin.json` (fetched from upstream for external plugins). Any
fetch or parse failure aborts the run without touching `marketplace.json`.

Plugins live directly under `plugins/`, never nested deeper.

## Required Files Per Plugin

- `.claude-plugin/plugin.json`, with at least `name`, `version` and `description`
- `README.md` covering what the plugin does and how to run it

A `LICENSE` is not required unless the plugin vendors licensed upstream code.

Declare components explicitly in `plugin.json` (`commands`, `agents`,
`skills`, `hooks`, `mcpServers`) even though Claude Code auto-discovers them.
The exception is `hooks/hooks.json`, which loads automatically and
must not be declared again (it causes a "duplicate hooks file" error).

## External Plugins

Two ways to bring in a plugin from another repo:

- **List it**: add its source object to `external-repos.json`. Installs pull
  straight from upstream; there is no local copy.
  ```json
  { "source": "git-subdir", "url": "openai/codex-plugin-cc", "path": "plugins/codex" }
  ```
  Supported types: `github`, `url`, `git-subdir` (with optional `ref`/`sha`).
- **Vendor it**: `git submodule add <url> plugins/<name>` when you want to edit
  or pin it. The generator picks it up as a local plugin.

A repo that ships `.claude-plugin/marketplace.json` instead of `plugin.json`
is a marketplace, not a plugin: add it with `/plugin marketplace add` rather
than listing it here.

## Runtime State and Logs

Anything a plugin writes at runtime goes under `.skogai/` in the session's
working directory, namespaced by plugin:

```
.skogai/logs/<plugin-name>/log.jsonl
```

These paths are gitignored. Never write runtime output into the plugin's own
directory.

## Per-Project Plugin Settings

A plugin that needs user configuration reads it from
`.claude/<plugin-name>.local.md`: YAML frontmatter for settings, with the
markdown body for notes or prompt text. See the `plugin-settings` skill.
These files are per-user and gitignored (`.claude/*.local.md`). A plugin
must behave sensibly when its settings file is missing.

## Adding a Plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json` and `README.md`.
2. Run `bash scripts/generate-marketplace-json.sh`.
3. Run `claude plugin validate plugins/<name>`.
4. Test locally with `claude --plugin-dir plugins/<name>`.
