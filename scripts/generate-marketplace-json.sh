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
TEMP_FILE=$(mktemp)
CLONE_DIR=$(mktemp -d)
trap 'rm -rf "$CLONE_DIR"' EXIT

echo -e "${YELLOW}Generating marketplace.json from discovered plugins...${NC}"

# Calculate SHA256 of original file
ORIGINAL_SHA=$(shasum -a 256 "$MARKETPLACE_JSON" | awk '{print $1}')

# Extract the marketplace metadata (everything except plugins array)
MARKETPLACE_HEADER=$(jq 'del(.plugins)' "$MARKETPLACE_JSON")

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
    # Bare name: resolved under metadata.pluginRoot (./plugins/).
    DIR_NAME=$(basename "$PLUGIN_DIR")

    PLUGIN_DATA=$(cat "$plugin_file")
    ENTRY=$(build_plugin_entry "$PLUGIN_DATA" "$(jq -n --arg s "$DIR_NAME" '$s')" "$DIR_NAME") || continue

    PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson entry "$ENTRY" '. + [$entry]')
    echo -e "${GREEN}  Added: $(echo "$ENTRY" | jq -r '.name')${NC}"
done <<< "$PLUGIN_FILES"

# --- External plugins: listed in .claude-plugin/external-repos.json ---
#
# external-repos.json is an array of plugin source objects, exactly as they
# appear in marketplace.json (github, url or git-subdir). Each run fetches the
# plugin's .claude-plugin/plugin.json for name and description. Any failure
# aborts the run before marketplace.json is touched.

die() {
    echo -e "${RED}Error: $*${NC}" >&2
    exit 1
}

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

        PLUGIN_DATA=""
        if [ -n "$GH_REPO" ] && command -v gh >/dev/null; then
            PLUGIN_DATA=$(gh api -H "Accept: application/vnd.github.raw" \
                "repos/$GH_REPO/contents/$MANIFEST_PATH${COMMIT:+?ref=$COMMIT}" 2>/dev/null) || PLUGIN_DATA=""
        fi
        if [ -z "$PLUGIN_DATA" ]; then
            # Blobless sparse clone: only the manifest is downloaded.
            DEST="$CLONE_DIR/$i"
            git clone --quiet --no-checkout --filter=blob:none ${REF:+--branch "$REF"} "$URL" "$DEST" \
                || die "could not clone $URL"
            PLUGIN_DATA=$(git -C "$DEST" show "${SHA:-HEAD}:$MANIFEST_PATH" 2>/dev/null) \
                || die "$URL has no $MANIFEST_PATH${COMMIT:+ at $COMMIT}"
        fi

        echo "$PLUGIN_DATA" | jq -e '.name | type == "string" and length > 0' >/dev/null 2>&1 \
            || die "$URL: $MANIFEST_PATH is not valid JSON or has no name"

        ENTRY=$(build_plugin_entry "$PLUGIN_DATA" "$SOURCE" "")
        PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq --argjson entry "$ENTRY" '. + [$entry]')
        echo -e "${GREEN}  Added (external): $(echo "$ENTRY" | jq -r '.name')${NC}"
    done
fi

# Sort plugins alphabetically by name
PLUGINS_JSON=$(echo "$PLUGINS_JSON" | jq 'sort_by(.name)')

# Combine marketplace metadata with plugins array
FINAL_JSON=$(echo "$MARKETPLACE_HEADER" | jq --argjson plugins "$PLUGINS_JSON" '. + {plugins: $plugins}')

# Write to marketplace.json with proper formatting
echo "$FINAL_JSON" | jq '.' > "$TEMP_FILE"

# Calculate SHA256 of new file
NEW_SHA=$(shasum -a 256 "$TEMP_FILE" | awk '{print $1}')

# Check if content changed
if [ "$ORIGINAL_SHA" != "$NEW_SHA" ]; then
    echo -e "${YELLOW}Content changed, incrementing patch version...${NC}"

    # Extract current version
    CURRENT_VERSION=$(echo "$MARKETPLACE_HEADER" | jq -r '.version // "1.0.0"')

    # Parse version components (major.minor.patch)
    IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

    # Increment patch version
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

    echo -e "${GREEN}Version: $CURRENT_VERSION -> $NEW_VERSION${NC}"

    # Update the marketplace header with new version
    MARKETPLACE_HEADER=$(echo "$MARKETPLACE_HEADER" | jq --arg version "$NEW_VERSION" '.version = $version')

    # Regenerate with new version
    FINAL_JSON=$(echo "$MARKETPLACE_HEADER" | jq --argjson plugins "$PLUGINS_JSON" '. + {plugins: $plugins}')
    echo "$FINAL_JSON" | jq '.' > "$TEMP_FILE"
fi

# Replace the original file
mv "$TEMP_FILE" "$MARKETPLACE_JSON"

echo -e "${GREEN}Successfully updated $MARKETPLACE_JSON${NC}"
echo -e "${GREEN}Total plugins: $(echo "$PLUGINS_JSON" | jq 'length')${NC}"
