# skogai-marketplace Conventions

How plugins are laid out in this repository (`skogai-marketplace`), as
distinct from the generic Claude Code plugin spec in SKILL.md. Consult this
file when adding or auditing a plugin here, not when explaining plugin
structure in the abstract.

## Repository Layout

```
.claude-plugin/marketplace.json   the marketplace manifest
plugins/<name>/                   one directory per plugin
projects/<name>/                  larger projects (git submodules), not plugins by default
plugin-skills/                    reference skills about building plugins
docs/                             mirrored Claude Code docs (read-only reference)
.skogai/                          local runtime state, gitignored
```

## Marketplace Manifest

`.claude-plugin/marketplace.json` sets `metadata.pluginRoot` to `./plugins/`,
so entries use **bare names** as their source:

```json
{ "name": "hook-tap", "source": "hook-tap", "description": "..." }
```

A bare name (no `/`) resolves under `pluginRoot`, giving `./plugins/hook-tap`.
A source that starts with `./` is resolved from the **marketplace root**
instead, ignoring `pluginRoot`, so `"source": "./hook-tap"` points at a
`./hook-tap` that does not exist. Bare names require Claude Code v2.1.239+.

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

Code from another repo comes in as a **git submodule** under `plugins/` (or
`projects/` if it is not a plugin itself). Check what the submodule
actually contains before adding a marketplace entry: a repo that ships
`.claude-plugin/marketplace.json` instead of `plugin.json` is a marketplace,
not a plugin, and should be added on its own with `/plugin marketplace add`
rather than listed as a plugin source here.

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
2. Add an entry to `.claude-plugin/marketplace.json` with `"source": "<name>"`.
3. Run `claude plugin validate plugins/<name>`.
4. Test locally with `claude --plugin-dir plugins/<name>`.
