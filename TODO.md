# TODO

## Automation

Manual steps from CLAUDE.md that could be enforced instead of remembered.

- [ ] **`docs/` is read-only** — `permissions.deny` entries `Edit(docs/**)` and `Write(docs/**)` in `.claude/settings.json`.
- [x] **Marketplace entry consistency** — `scripts/generate-marketplace-json.sh --check` fails when `marketplace.json` differs from what the generator writes; run from the pre-commit hook and the `marketplace` workflow.
- [ ] **Block hand edits** — `permissions.deny` entries `Edit(.claude-plugin/marketplace.json)` and `Write(.claude-plugin/marketplace.json)` in `.claude/settings.json`.
- [ ] **Plugin validation** — run `claude plugin validate plugins/<name>` for each changed plugin. Run it, together with the consistency script above, from a git pre-commit hook (tool hooks can't target `git commit` specifically).
- [ ] **`docs/` freshness** — the sync scripts were removed. Restore a sync script, and optionally add a SessionStart warning when `docs/synced-at.txt` is older than N days.

## Next steps

- [ ] Review `todo/` merge into or add as marketplace plugins.
- [ ] Add a `*.test.ts` for skogai-core so `claude plugin test` has something to run.

## User input

- [x] add `git diff` and `git diff --cached` generation to `.skogai/tmp/git-diff` and `.skogai/tmp/git-diff-cached` (`scripts/write-state.sh`)
- [ ] add a "user messages"-log for only user messages. end goal being "look over user messages and see if potential changes of intent have happened and set up new tasks for them"
