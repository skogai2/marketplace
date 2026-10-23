---
type: module
name: type
description: instance schemas, every module's schema/<x>.json checked against its instances
command: argc.sh
tools: [yq, ajv]
requires: [core]
files:
  - tests/contract.bats
config: {}
---

# type

a module that requires `type` says what its files look like: each
`schema/<x>.json` it offers (JSON Schema 2020-12) is checked against the
frontmatter of every instance, the files its config key `<module>.schema.<x>`
globs.

```markdown
---
name: memory
requires: [core, type]
files:
  - schema/
config:
  dir: memory
  schema:
    entry: <dir>/*.md
---
```

the glob is bash (globstar, extglob, nullglob), relative to the local dir
(`.skogai`). `<key>` in it is the same module's resolved `<module>.<key>`:
with the above `<dir>/*.md` is `.skogai/memory/*.md`, and moves when
`memory.dir` does; `<dir>/!(<index>)` is every file there but the index. a
schema with no glob is an error.

| command | |
|---|---|
| `check [module]...` | every instance against its schema, one line per file with problems: `module<TAB>path<TAB>message`, a file's problems joined with `; `; exit 1 on any |
| `check --schema <module>.<x> <file>...` | the same, for these files against that schema |
| `ls [module]...` | `module<TAB>schema<TAB>glob<TAB>instances` |

without a module both take every module that requires `type`. frontmatter is
read with `yq`, validated with `ajv --spec=draft2020 --strict=true`, so a
schema with an unknown keyword is a problem too.

## tests

a module that requires `type` ships, in its source only (not in `files:`),
`tests/fixtures/<x>/valid/*` and `tests/fixtures/<x>/invalid/*` for each
`schema/<x>.json`, both non-empty.

`tests/contract.bats` runs against every module that requires `type`: each
`schema/*.json` compiles, each has a glob, each has both fixture dirs, every
valid fixture passes and every invalid one fails `check --schema`, and
`skogai type check <module>` passes in a fresh repo.
