#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
EXTERNAL_REPOS_JSON="$REPO_ROOT/.claude-plugin/external-repos.json"
HEADER_JSON="$REPO_ROOT/.claude-plugin/marketplace-header.json"
TEMP_FILE=$(mktemp)
CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$CLONE_DIR" "$TEMP_FILE"' EXIT

# --check: regenerate in memory and fail if marketplace.json differs from what
# this script would write (ignoring the version bump). Never writes anything.
CHECK=false
[ "${1:-}" = "--check" ] && CHECK=true

die() {
    echo -e "${RED}Error: $*${NC}" >&2
    exit 1
}

# jq silently keeps the last of duplicate keys, so a botched hand edit can
# parse fine and still mean something else. Reject them.
python3 - "$MARKETPLACE_JSON" "$HEADER_JSON" "$EXTERNAL_REPOS_JSON" <<'PY' || exit 1
import json, sys
def no_dupes(pairs):
    keys = [k for k, _ in pairs]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        raise ValueError("duplicate key(s): " + ", ".join(dupes))
    return dict(pairs)
for path in sys.argv[1:]:
    try:
        with open(path) as f:
            json.load(f, object_pairs_hook=no_dupes)
    except FileNotFoundError:
        pass
    except ValueError as e:
        sys.exit(f"\033[0;31mError: {path}: {e}\033[0m")
PY

echo -e "${YELLOW}Generating marketplace.json from discovered plugins...${NC}"

# Marketplace metadata comes from marketplace-header.json; only "version" is
# carried over from the current marketplace.json (it's bumped below).
jq -e '.name and .owner.name' "$HEADER_JSON" >/dev/null 2>&1 || {
    echo -e "${RED}Error: $HEADER_JSON missing or lacks name or owner.name${NC}" >&2
    exit 1
}
MARKETPLACE_HEADER=$(jq -n --slurpfile h "$HEADER_JSON" --slurpfile m "$MARKETPLACE_JSON" \
    '$h[0] as $h | {"$schema": $h["$schema"], name: $h.name, version: ($m[0].version // "1.0.0")} + ($h | del(.version))
     | with_entries(select(.value != null))')

# Build one marketplace plugin entry: only name, source and description.
# Everything else (version, author, components) stays in plugin.json, which
# Claude Code reads anyway; copying components here would duplicate them
# under strict mode.
build_plugin_entry() {
    local plugin_data="$1"
    local source_json="$2"
    local fallback_name="$3"

    jq -n --argjson p "$plugin_data" --argjson source "$source_json" --arg fallback "$fallback_name" '
        ($p.name // $fallback) as $name
        | {name: $name, source: $source}
        + (if ($p.description // "") != "" then {description: $p.description} else {} end)'
}

# --- Local plugins: discovered from */.claude-plugin/plugin.json ---

PLUGIN_FILES=$(find "$REPO_ROOT/plugins" -mindepth 3 -maxdepth 3 -path "*/.claude-plugin/plugin.json" | sort)

for dir in "$REPO_ROOT"/plugins/*/; do
    [ -f "$dir.claude-plugin/plugin.json" ] \
        || echo -e "${YELLOW}Warning: plugins/$(basename "$dir") has no .claude-plugin/plugin.json; skipped (list external plugins in external-repos.json)${NC}" >&2
done

if [ -z "$PLUGIN_FILES" ]; then
    echo -e "${RED}No plugin.json files found!${NC}"
    exit 1
fi

echo -e "${GREEN}Found $(echo "$PLUGIN_FILES" | wc -l | tr -d ' ') local plugin(s)${NC}"

PLUGINS_JSON="[]"

while IFS= read -r plugin_file; do
    [ -f "$plugin_file" ] || continue

    echo "Processing: $plugin_file"

    PLUGIN_DIR=$(dirname "$(dirname "$plugin_file")")
    # Written out as ./plugins/<dir>: claude.ai organization sync rejects bare
    # names under metadata.pluginRoot.
    DIR_NAME=$(basename "$PLUGIN_DIR")

    PLUGIN_DATA=$(cat "$plugin_file")
    ENTRY=$(build_plugin_entry "$PLUGIN_DATA" "$(jq -n --arg s "./plugins/$DIR_NAME" '$s')" "$DIR_NAME") || continue

    PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson entry "$ENTRY" '. + [$entry]')
    echo -e "${GREEN}  Added: $(echo "$ENTRY" | jq -r '.name')${NC}"
done <<< "$PLUGIN_FILES"

# --- External plugins: listed in .claude-plugin/external-repos.json ---
#
# external-repos.json is an array of plugin source objects, exactly as they
# appear in marketplace.json (github, url or git-subdir). Each run fetches the
# plugin's .claude-plugin/plugin.json for name and description. plugin.json is
# optional, so a repo without one falls back to the entry in its own
# .claude-plugin/marketplace.json whose source is "./", and gets "strict":
# false so the entry is its manifest (claude.ai organization sync requires
# that). Any failure aborts the run before marketplace.json is touched.

if [ -f "$EXTERNAL_REPOS_JSON" ]; then
    EXTERNAL_COUNT=$(jq 'length' "$EXTERNAL_REPOS_JSON")
    echo -e "${GREEN}Found $EXTERNAL_COUNT external plugin(s)${NC}"

    for i in $(seq 0 $((EXTERNAL_COUNT - 1))); do
        SOURCE=$(jq -c ".[$i]" "$EXTERNAL_REPOS_JSON")
        TYPE=$(echo "$SOURCE" | jq -r '.source')
        REF=$(echo "$SOURCE" | jq -r '.ref // empty')
        SHA=$(echo "$SOURCE" | jq -r '.sha // empty')
        SUBDIR=$(echo "$SOURCE" | jq -r '.path // empty')
        GH_REPO=""

        case "$TYPE" in
            github)
                GH_REPO=$(echo "$SOURCE" | jq -r '.repo')
                URL="https://github.com/$GH_REPO.git"
                ;;
            url)
                URL=$(echo "$SOURCE" | jq -r '.url')
                ;;
            git-subdir)
                URL=$(echo "$SOURCE" | jq -r '.url')
                # owner/repo shorthand
                if [[ "$URL" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
                    GH_REPO="$URL"
                    URL="https://github.com/$URL.git"
                fi
                ;;
            *)
                die "external entry $i: unsupported source type '$TYPE': $SOURCE"
                ;;
        esac
        [ -n "$URL" ] && [ "$URL" != "null" ] || die "external entry $i has no url/repo: $SOURCE"
        if [ -z "$GH_REPO" ] && [[ "$URL" =~ github\.com[:/]([^/]+/[^/]+)$ ]]; then
            GH_REPO="${BASH_REMATCH[1]%.git}"
        fi

        MANIFEST_PATH="${SUBDIR:+${SUBDIR#./}/}.claude-plugin/plugin.json"
        COMMIT="${SHA:-$REF}"
        echo "Fetching $MANIFEST_PATH from $URL${COMMIT:+ @ $COMMIT}"

        OWN_MARKETPLACE_PATH="${SUBDIR:+${SUBDIR#./}/}.claude-plugin/marketplace.json"
        DEST="$CLONE_DIR/$i"

        # Prints one file from the external repo, or nothing if it's missing.
        fetch_file() {
            local path="$1"
            if [ -n "$GH_REPO" ] && command -v gh >/dev/null; then
                local out
                out=$(gh api -H "Accept: application/vnd.github.raw" \
                    "repos/$GH_REPO/contents/$path${COMMIT:+?ref=$COMMIT}" 2>/dev/null) \
                    && { echo "$out"; return; }
            fi
            # Blobless clone: only the files read here are downloaded.
            [ -d "$DEST" ] || git clone --quiet --no-checkout --filter=blob:none ${REF:+--branch "$REF"} "$URL" "$DEST" \
                || die "could not clone $URL"
            git -C "$DEST" show "${SHA:-HEAD}:$path" 2>/dev/null || true
        }

        PLUGIN_DATA=$(fetch_file "$MANIFEST_PATH")
        INLINE_MANIFEST=false
        if [ -z "$PLUGIN_DATA" ]; then
            INLINE_MANIFEST=true
            PLUGIN_DATA=$(fetch_file "$OWN_MARKETPLACE_PATH" \
                | jq -c '[.plugins[]? | select(.source == "./" or .source == ".")] | if length == 1 then .[0] else empty end' 2>/dev/null)
            [ -n "$PLUGIN_DATA" ] \
                || die "$URL has neither $MANIFEST_PATH nor a single \"./\" entry in $OWN_MARKETPLACE_PATH${COMMIT:+ at $COMMIT}"
            echo "  (no plugin.json; using the entry in $OWN_MARKETPLACE_PATH)"
        fi

        echo "$PLUGIN_DATA" | jq -e '.name | type == "string" and length > 0' >/dev/null 2>&1 \
            || die "$URL: $MANIFEST_PATH is not valid JSON or has no name"

        ENTRY=$(build_plugin_entry "$PLUGIN_DATA" "$SOURCE" "")
        if $INLINE_MANIFEST; then
            ENTRY=$(echo "$ENTRY" | jq '. + {strict: false}')
        fi
        PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson entry "$ENTRY" '. + [$entry]')
        echo -e "${GREEN}  Added (external): $(echo "$ENTRY" | jq -r '.name')${NC}"
    done
fi

# Two plugins with one name would shadow each other.
DUPES=$(echo "$PLUGINS_JSON" | jq -r 'group_by(.name)[] | select(length > 1) | .[0].name')
[ -z "$DUPES" ] || die "duplicate plugin name(s): $DUPES"

# Sort plugins alphabetically by name
PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq 'sort_by(.name)')

CURRENT_VERSION=$(echo "$MARKETPLACE_HEADER" | jq -r '.version // "1.0.0"')

# Combine marketplace metadata with plugins array
echo "$MARKETPLACE_HEADER" | jq --argjson plugins "$PLUGINS_JSON" '. + {plugins: $plugins}' > "$TEMP_FILE"

if $CHECK; then
    if cmp -s "$TEMP_FILE" "$MARKETPLACE_JSON"; then
        echo -e "${GREEN}$MARKETPLACE_JSON is up to date${NC}"
        exit 0
    fi
    echo -e "${RED}$MARKETPLACE_JSON is out of date or was hand-edited. Run scripts/generate-marketplace-json.sh.${NC}" >&2
    diff -u "$MARKETPLACE_JSON" "$TEMP_FILE" >&2 || true
    exit 1
fi

if ! cmp -s "$TEMP_FILE" "$MARKETPLACE_JSON"; then
    echo -e "${YELLOW}Content changed, incrementing patch version...${NC}"

    # Parse version components (major.minor.patch)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
    NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

    echo -e "${GREEN}Version: $CURRENT_VERSION -> $NEW_VERSION${NC}"

    jq --arg version "$NEW_VERSION" '.version = $version' "$TEMP_FILE" > "$MARKETPLACE_JSON"
fi

echo -e "${GREEN}Successfully updated $MARKETPLACE_JSON${NC}"
echo -e "${GREEN}Total plugins: $(echo "$PLUGINS_JSON" | jq 'length')${NC}"
