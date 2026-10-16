# Config: one key space, two formats

Status: **proposed**. skogai-core's own settings (`scripts/settings.sh`, `.claude/skogai-core.local.md`) work today and are the first thing to port.

## In one paragraph

dash-skogai already owns config: `~/skogai/dash-skogai/type/config.md` specifies it and `~/skogai/dash-skogai/bin/skogai config` implements it, as git-config files folded base → global → local → env. So we don't build a second CLI. We add markdown frontmatter as **file layers** on top of dash's stack, flattened into the same dotted key space, and skogai-core reads everything through `skogai config`.

## What exists

Facts gathered with the `skogai-69` and `skogai-e4` sessions on 2026-10-16.

| Thing | Where | Notes |
|---|---|---|
| Config spec | `~/skogai/dash-skogai/type/config.md` | `type: type`, `owns: [config]`. Layers, commands, merge rule, key list |
| Base layer | `~/skogai/dash-skogai/config` | git-config: `stage`, `commit`, `merge` × `on-stop`, `on-user-prompt-submit`, all `false` |
| CLI | `~/skogai/dash-skogai/bin/skogai` | argc + `git config -f`. `get`/`set`/`unset`/`list` with `--show-origin`, `env` (export lines), `files` |
| Global layer | `~/.skogai/config` or `$SKOGAI_GLOBAL_CONFIG` | Missing. `~/.skogai` is a git repo holding only `.skogai/logs` |
| Local layer | `<repo>/.skogai/config` or `$SKOGAI_LOCAL_CONFIG` | Missing everywhere |
| Git-step env | `~/.config/mise/config.toml:197-202` | `SKOGAI_{STAGE,COMMIT,MERGE}_ON_*`. Already dash's env names for `stage.on-stop` etc. |
| Who/mode env | `/skogai/mise.toml:13-15` | `SKOGAI_USER` (claude/skogix), `SKOGAI_MODE` (remote/workstation), `FNOX_PROFILE` |
| `XDG_SKOGAI_DIR`, `XDG_SKOGAI_CONFIG_DIR` | systemd user environment | Source file unknown. No config layer uses them |
| Secrets | `/skogai/fnox.toml` | age-encrypted, profiles `skogix` and `claude`. Only reach tasks that list them |

`skogai config list --show-origin`, run from `~/skogai` in the marketplace session, shows every key coming from `env:SKOGAI_*`, all `false`. `skogai-69` sees `STAGE`/`COMMIT=true` from mise in its session. The same key has different values in two sessions on one machine, and `--show-origin` can only say "env", not who set the env.

## Model

```
resolve = fold(replace-per-key, [base, global, local, file, file.local, env])
```

| # | Layer | File | Format |
|---|---|---|---|
| 1 | base | `dash-skogai/config` | git-config |
| 2 | global | `~/.skogai/config` (`$SKOGAI_GLOBAL_CONFIG`) | git-config |
| 3 | local | `<repo>/.skogai/config` (`$SKOGAI_LOCAL_CONFIG`) | git-config |
| 4 | file | `X.md`, only with `--file X.md` | frontmatter |
| 5 | file local | `X.local.md`, comes with 4 | frontmatter |
| 6 | env | `SKOGAI_A_B_C` for key `a.b-c` | env |

Layers 1–3 and 6 are dash's spec, unchanged. 4–5 are the addition: a document's frontmatter, plus its `.local.md` overlay the way `CLAUDE.md` has `CLAUDE.local.md`. There is no separate "project layer": a repo is layer 3, and anything finer is a file.

### Frontmatter flattens to keys

A frontmatter tree becomes dotted keys, so both formats share one key space and dash's replace-per-key rule:

```yaml
---
enabled: true
git: { stage: { on-stop: true } }
events: [Stop, "Post*"]
---
```

```
enabled            = true
git.stage.on-stop  = true
events             = Stop        (multi-valued key)
events             = Post*
```

- **Replace-per-key on flat keys is deep merge on maps.** A file setting `git.stage.on-stop` leaves `git.commit.*` from lower layers alone. dash's "replace-only" rule needs no change.
- **A list is one multi-valued key**, replaced as a whole. git-config already has multi-valued keys (`git config --add`, `--get-all`). Never flatten lists to `events.0`, `events.1`: they'd merge index by index.
- **`--scope NAME`** mounts a file's keys under `NAME.`, so `.claude/skogai-core.local.md` with `enabled: false` is `skogai-core.enabled`.
- Checked with yq 4.54.1: `yq --front-matter=extract 'select(document_index == 0) | .. | select(tag != "!!map" and tag != "!!seq") | (path | map(tostring) | join(".")) + "=" + tostring'`. Lists need a variant that emits one line per item under the parent key. The `document_index == 0` matters: a body with `---` lines reads as more YAML documents otherwise.

### Writes

- `set` writes the local layer, `--global` the global one (dash today). Add `--file X.md`, which writes `X.local.md`, never the committed `X.md`.
- git-config layers write through `git config -f`, which takes its own `.lock` file, so parallel hooks can't interleave. Frontmatter writes use `yq -i --front-matter=process`, which keeps comments, the body and `---` lines in the body (checked), under `flock`.

### Config vs state

- **Config** is what people edit. Tools only write it on `set`.
- **State** is what hooks write: the last event, counters. Same CLI, separate file (`.skogai/state`, git-config), never part of the resolve stack. A hook rewriting state can't clobber an edit someone is making.

### Env and mise

- Today mise is where `SKOGAI_*` env gets built, by hand, duplicating what config should own.
- Proposed direction: config is the source, mise is delivery. mise's `[env] _.source` runs `skogai config env`, and the six `SKOGAI_*_ON_*` literals leave `~/.config/mise/config.toml`.
- Gotchas from `~/skogai/wip/mise/gotchas.md` that bear on this:
  - mise shims re-apply `[env]`, so mise beats a hand-exported `SKOGAI_*` when a tool runs through a shim. "env wins" really means "whichever env was applied last wins".
  - A plain Bash tool call sees none of a repo's `[env]`. Use `mise env -s bash` written to `CLAUDE_ENV_FILE`.
  - A missing `_.source` file is skipped without warning.

### Secrets

Never in config, in any layer. Secrets live in fnox and only reach tasks that declare them. A config key may hold a fnox key *name* (`deploy.token-ref = CF_TOKEN`), never a value. `FNOX_*` env stays derived in mise.

## Changes, in order

1. **Fix `skogai` on `PATH`.** `~/.local/bin/skogai` is a uv-installed Python skogcli that fails with `ModuleNotFoundError: No module named 'skogai'`, and it shadows dash's `bin/skogai`. Until fixed, nothing can call `skogai config` by name.
2. **dash `bin/skogai`:** add `--file X.md [--scope NAME]` to `get`/`list`/`set`, with the flattening above, and multi-valued keys (`_resolve` keeps only the last value per key today).
3. **skogai-core `git-steps.sh`:** done. It reads `skogai config list` from the git root and falls back to the `SKOGAI_*_ON_*` env vars when no working `skogai` is on PATH. The env names match dash's keys, so nothing changes until a config file sets one.
4. **skogai-core `settings.sh` and `register.ts`:** read `skogai config get --file <root>/.claude/skogai-core.md --scope skogai-core <key>`, keeping the awk reader as the fallback when `skogai` isn't installed. Plugins are shared through the marketplace and must work without dash.
5. **mise:** move the `SKOGAI_*_ON_*` values into `~/.skogai/config` and source them back through `skogai config env`.
6. **Delete** `~/marketplace/scripts/parse-frontmatter.sh` and the copies of `validate-settings.sh` / `example.local.md` in `dash-skogai/`, once the dash type checks config.

## Decisions for skogix

- **Format split.** This doc proposes git-config for layers 1–3, frontmatter for files. The alternative is frontmatter everywhere (`.skogai/config.md`), which makes dash's existing CLI and spec change.
- **Global layer.** `~/.skogai/config`, as dash says, or `/skogai` per decision 0005, or `$XDG_SKOGAI_CONFIG_DIR`? Today `~/.skogai` is nearly empty and the XDG vars are set but used by nothing.
- **Where the XDG vars come from.** They're in the systemd user environment with no known source file. And this session's `SKOGAI_*` are all `false` while mise says `true`.
- **Strict keys** (dash TODO "strict keys declared by types, or free-form?"). A type could declare a plugin's keys, types and defaults, and its defaults would be the base layer for that scope.
- **Env names for scoped keys.** `skogai-core.events` → `SKOGAI_SKOGAI_CORE_EVENTS` follows dash's rule but is clumsy.

## Left out on purpose

- A project layer distinct from local.
- Includes, remote config, encryption.
- Appending lists across layers. Replacing is predictable; an append can't be undone by a higher layer.
