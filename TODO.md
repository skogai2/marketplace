# TODO

## Automation

Manual steps from CLAUDE.md that could be enforced instead of remembered.

- [ ] **Submodule init** — SessionStart hook that runs `git submodule update --init` when `git submodule status` shows a `-` prefix. Alternatively `git config submodule.recurse true` so pulls/checkouts keep them in sync.
- [ ] **`docs/` is read-only** — `permissions.deny` entries `Edit(docs/**)` and `Write(docs/**)` in `.claude/settings.json`.
- [ ] **Marketplace entry consistency** — a small `jq` script checking that every `plugins[]` entry:
  - has only `name`, `source`, `description` (no `version`)
  - has `name` == basename of `source`, kebab-case
  - resolves to an existing directory under `pluginRoot` with a `.claude-plugin/plugin.json` (would have caught `loadout`)
  - is in alphabetical order
- [ ] **Plugin validation** — run `claude plugin validate plugins/<name>` for each changed plugin. Run it, together with the consistency script above, from a git pre-commit hook (tool hooks can't target `git commit` specifically).
- [ ] **`docs/` freshness** — the sync scripts were removed. Restore a sync script, and optionally add a SessionStart warning when `docs/synced-at.txt` is older than N days.

## Next steps

- [ ] Move the `loadout` submodule from `projects/loadout` to `plugins/loadout` (`git mv` + `.gitmodules`); it currently shows as deleted in the working tree.
- [ ] Review `plugin-skills/` (`plugin-structure`, `plugin-settings`): merge into or add as marketplace plugins; drop or rewrite `plugin-structure/references/marketplace-repo-conventions.md`, which describes a different repo.
- [ ] Update the hook-tap README: log path is `.skogai/logs/hook-tap/log.jsonl` (not `plugins/hook-tap/log.jsonl`), and it still mentions `~/skogai-fleet`.
- [ ] Add a `*.test.ts` for hook-tap so `claude plugin test` has something to run.
