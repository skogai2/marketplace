# q2 — how should apm relate to the marketplace?

status: answered
act: ask
kind: choice
agent: 4f39f354-2b4d-4b21-bf75-d0367004c640
cwd: .
asked at: 2026-10-25T12:32:43.591423+00:00

## Files

- /home/skogix/.local/src/marketplace/apm.yml
- /home/skogix/.local/src/marketplace/.claude-plugin/marketplace.json
- /home/skogix/.local/src/marketplace/scripts/generate-marketplace-json.sh

## Options

- consumer only — apm.yml manages this repo's own dev deps (mcp, skills); the generator keeps owning marketplace.json; drop the scaffold marketplace: block  (★◐)
- replace generator — move the 6 entries into apm.yml marketplace.packages, apm pack writes marketplace.json; loses strict:false and renames, needs checking
- both outputs — keep generator for claude, try apm pack only for a codex output (.agents/plugins/marketplace.json)
- drop apm here — remove apm.yml, apm.lock.yaml, build/, .mcp.json

## Recommendation

consumer only — med
apm pack does not emit strict or renames, which org sync and old-name cleanup need; the scaffold block would overwrite marketplace.json with acme-org/example-package

## Answer

consumer only
answered at: 2026-10-25T15:45:15.237849+00:00
