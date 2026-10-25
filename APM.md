# apm

what apm (`~/.local/src/apm`, 0.35.0) is, and what it does with this marketplace. `apm.yml` here is consumer-only (decided 2026-10-25): it declares this repo's own agent dependencies for `apm install`, and has no `marketplace:` block. the generator (`scripts/generate-marketplace-json.sh`) owns `.claude-plugin/marketplace.json`.

## what apm is

a package manager for agent context: `apm.yml` (manifest) + `apm.lock.yaml` (lockfile, pinned commits and content hashes). `apm install` copies primitives (skills, agents, commands, hooks, mcp servers) as loose files into each harness's project dir (`.claude/`, `.codex/`, `.github/`, ...). it is not a runtime and not a plugin installer for claude code: a plugin from a marketplace is taken apart into `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, `.claude/hooks/<plugin>/` and merged hook entries in `.claude/settings.json`. whole-plugin ("native") install exists only for copilot, and for codex at user scope.

one `apm.yml` serves two roles:

- consumer: `dependencies:` + `targets:`, then `apm install`. writes harness files and the lockfile.
- producer: `marketplace:` block, then `apm pack`. writes marketplace json for claude, codex and/or copilot.

with `targets:` or `dependencies:` present, `apm pack` also writes a root `.claude-plugin/plugin.json` (the repo packed as a plugin). `apm install` does not; this repo's `apm.yml` is consumer-only, so it is never packed.

## producer: `apm pack` (tested, then removed)

- a `marketplace:` block listing the same 6 entries, packed to a scratch `build/`.
- claude output: same names and descriptions as the generator, passes `claude plugin validate`. adds `version`, `ref`/`sha`, `tag_pattern`. no `strict` and no `renames`, which this marketplace needs.
- codex output (`outputs.codex`, every package needs `category:`): codex 0.164 reads it, and `codex plugin add` installs the whole plugin tree (bin/, modules/, ...) from `.claude-plugin/plugin.json`. the generator has no codex output, so this is what apm adds.
- descriptions are not read from local `plugin.json` and the remote lookup 404s, so they are written in `apm.yml` by hand. that duplicates what the generator reads.
- `apm marketplace check` reports commit-pinned remote refs as "not found" while `apm pack` resolves them.

## consumer: `apm install <plugin>@skogai-marketplace`

apm reads the generator's `.claude-plugin/marketplace.json` from github as is (`apm marketplace add skogai2/marketplace -r master`). results in a scratch project, `--target claude`:

| plugin | result |
|---|---|
| skogai-runner | skills fine; hook broken: only `bin/skogai` is copied, not `modules/` beside it |
| skogai-core | hooks broken: `events/*.sh` copied, the `../settings.sh` they source is not |
| skogai-council | fails: it is a git submodule, so the github tree has no files at `plugins/skogai-council` |
| open-knowledge-plugin | installs; warns about hidden unicode in one file |
| codex | installs; command frontmatter keys claude does not support are dropped |
| loadout | installs |

`apm audit` reported drift and an invalid hook container right after a clean install.

rule behind the hook breaks: apm copies the directory of the file a hook command names, not the plugin root. a hook that reaches outside its own directory breaks under apm.

## gotchas

- `APM_HOME` does not move `~/.apm/marketplaces.json`; use `HOME=<scratch>` to test without touching the real registry.
- `apm marketplace add <local path>` defaults to ref `main`; this repo is `master`, so pass `-r master`.

## append-only

- 2026-10-25: first test run; findings above.
- 2026-10-25: consumer-only chosen; `marketplace:` block and `build/` removed. the producer findings stay as the record of the test.
