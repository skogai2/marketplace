# q4 — publish a codex marketplace for real?

status: answered
act: ask
kind: choice
agent: 4f39f354-2b4d-4b21-bf75-d0367004c640
cwd: .
asked at: 2026-10-25T13:00:38.891649+00:00

## Files

- /home/skogix/.local/src/marketplace/APM.md
- /home/skogix/.local/src/marketplace/apm.yml
- /home/skogix/.local/src/marketplace/scripts/generate-marketplace-json.sh

## Options

- extend generator — add a codex output (.agents/plugins/marketplace.json) to generate-marketplace-json.sh; apm stays a test  (★◐)
- apm for codex — point apm's codex output at .agents/plugins/marketplace.json and commit it; generator keeps claude
- not yet — keep both outputs in build/ only

## Recommendation

extend generator — med
one source of truth; apm needs descriptions duplicated in apm.yml and adds a second tool to the pre-commit check

## Answer

not yet
answered at: 2026-10-25T15:47:07.403397+00:00
