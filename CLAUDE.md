# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Claude Code plugin marketplace (`skogai-marketplace`). No build, test suite, or CI — `.claude-plugin/marketplace.json` is hand-edited.

## Layout

- `metadata.pluginRoot` is `./plugins/`, so each plugin `source` is a bare name resolved under `plugins/` (`"hook-tap"` → `plugins/hook-tap`). `pluginRoot` is ignored for sources starting with `./` — those resolve from the repo root (see `docs/plugins/marketplace-reference.md`, "Bare names under pluginRoot"). All plugins, including submodules, live under `plugins/`.
- Marketplace entries carry only `name`, `source`, `description`; `name` is kebab-case and matches the directory. Versions go in each plugin's `.claude-plugin/plugin.json`, not the marketplace entry.
- Some plugins are git submodules (see `.gitmodules`). Run `git submodule update --init` before touching them — uninitialized submodules are empty directories.
- `docs/` is a synced snapshot of the Claude Code docs (date in `docs/synced-at.txt`). Treat it as the read-only reference for plugin/hook/marketplace APIs; never edit it.
- `plugin-skills/` holds reference skills to review and, where useful, merge into or add as marketplace plugins. Its `plugin-structure/references/marketplace-repo-conventions.md` describes a different repo (root-level plugins, Makefile-generated `marketplace.json`, `external-repos.json`) — none of that applies here.

## Validating

- `claude plugin validate plugins/<name>` — run after changing a plugin or its marketplace entry.
- `claude -p "reply with just OK" --plugin-dir plugins/<name>` — headless load check.
- `plugins/hook-tap/LEARNINGS.md` lists function-hook validator rules (string-literal event names, function-literal hooks, `$.noun.method()` only; one throwing hook stops the whole module loading). Read it before writing TypeScript hook modules.

## Git

Commit directly to `master`; short messages are fine.

