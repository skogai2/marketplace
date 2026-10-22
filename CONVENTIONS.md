# skogai-marketplace Conventions

How plugins are laid out in this repository and how `marketplace.json` is
built. `docs/` covers the generic Claude Code plugin spec; this file covers
only what is specific to this repo.

## Repository Layout

```
.claude-plugin/marketplace.json         generated marketplace manifest
.claude-plugin/marketplace-header.json  top-level marketplace fields
.claude-plugin/external-repos.json      plugins that live in other repos
plugins/<name>/                         one directory per local plugin
scripts/                                the generator and the pre-commit hook
docs/                                   synced Claude Code docs (read-only)
.skogai/                                workorders and journal; logs/ and tmp/ are gitignored
```

## Marketplace Manifest

`.claude-plugin/marketplace.json` is generated; never edit it by hand. Run:

```sh
scripts/generate-marketplace-json.sh
```

It builds the file from three inputs:

- `.claude-plugin/marketplace-header.json`: top-level fields (`name`, `owner`,
  `renames`, ...). `name` and `owner.name` are required.
- `plugins/*/.claude-plugin/plugin.json`: local plugins, written as
  `"source": "./plugins/<dir>"`. claude.ai organization sync rejects bare
  names under `metadata.pluginRoot`, so there is none. A directory under
  `plugins/` without `plugin.json` is skipped with a warning.
- `.claude-plugin/external-repos.json`: plugins in other repos, as an array of
  plugin source objects copied verbatim into `marketplace.json`.

Each entry carries only `name`, `source` and `description`, read from the
plugin's own `plugin.json`. Everything else (version, author, components)
stays in `plugin.json`, which Claude Code reads anyway. Entries are sorted by
name.

### What the generator checks

- Duplicate keys in any of the JSON inputs (jq would silently keep the last).
- Two plugins with the same name.
- External plugins whose manifest can't be fetched or has no `name`.

Any failure aborts the run without touching `marketplace.json`.

### Version

The marketplace `version` is carried over from the current
`marketplace.json` and its patch number is bumped only when the content
changes. A run that changes nothing leaves the file alone.

### Drift guard

`scripts/generate-marketplace-json.sh --check` regenerates in memory and
fails, printing a diff, if `marketplace.json` differs. It never writes. It
runs from:

- `scripts/git-hooks/pre-commit`, when a manifest under `.claude-plugin/` or
  `plugins/*/.claude-plugin/` is staged. Enable it with
  `git config core.hooksPath scripts/git-hooks`.
- the `marketplace` GitHub workflow, on pushes and PRs that touch those paths.

## External Plugins

Add the plugin's source object to `external-repos.json`. Installs pull
straight from upstream; there is no local copy and no submodule.

```json
{ "source": "git-subdir", "url": "openai/codex-plugin-cc", "path": "plugins/codex" }
```

Supported types: `github` (`repo`), `url` and `git-subdir` (`url` as a full
URL or `owner/repo`, plus `path`), each with optional `ref`/`sha`. Pin with
`ref`/`sha` rather than vendoring.

On each run the generator fetches the plugin's `.claude-plugin/plugin.json`
for name and description: through `gh api` for GitHub repos when `gh` is
installed, otherwise from a blobless clone. A repo without `plugin.json` can
still be listed when its own `.claude-plugin/marketplace.json` has a single
`"./"` entry: the generator takes name and description from it and adds
`"strict": false`, so the entry is the manifest (organization sync requires
that for an inline manifest).

## Required Files Per Plugin

- `.claude-plugin/plugin.json`, with at least `name` (kebab-case, matching the
  directory), `version` and `description`
- `README.md` covering what the plugin does and how to run it

A `LICENSE` is not required unless the plugin vendors licensed upstream code.

Declare components explicitly in `plugin.json` (`commands`, `agents`,
`skills`, `hooks`, `mcpServers`) even though Claude Code auto-discovers them.
The exception is `hooks/hooks.json`, which loads automatically and must not
be declared again (it causes a "duplicate hooks file" error).

These rules are not enforced by the generator; `claude plugin validate
plugins/<name>` catches some of them.

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
markdown body for notes. These files are per-user and gitignored
(`.claude/*.local.md`). A plugin must behave sensibly when its settings file
is missing.

skogai-core is the reference implementation: `plugins/skogai-core/scripts/settings.sh`
reads the file (through `skogai config` when available), `examples/skogai-core.local.md`
is the template, `scripts/validate-settings.sh` checks it, and `CONFIG.md`
explains how it layers with dash's `skogai config`.

## Adding a Plugin

Use the `/add-plugin` skill. It creates the plugin or external entry,
regenerates `marketplace.json` and validates the result.
