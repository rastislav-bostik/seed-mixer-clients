#!/usr/bin/env bash
# Sync the live seed-mixer OpenAPI schema into this directory, track schema
# changes, and maintain an internal version log. The backend's own
# `info.version` field is unreliable ("0.0.0"), so we track our own snapshots
# by content hash.
#
# Usage: shared/api-contract/sync.sh [--source URL]
#
# Side effects:
#   - rewrites openapi.json with a normalized (jq-sorted) snapshot
#   - on hash change: appends a row to CHANGELOG.md with the diff summary
#   - saves a timestamped snapshot under snapshots/ (history)
#
# No external deps beyond curl + jq + sha256sum (or shasum on macOS).

set -euo pipefail

SOURCE_URL="${1:-https://seed-mixer-api.onrender.com/openapi.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENAPI_FILE="$SCRIPT_DIR/openapi.json"
CHANGELOG_FILE="$SCRIPT_DIR/CHANGELOG.md"
SNAPSHOTS_DIR="$SCRIPT_DIR/snapshots"

mkdir -p "$SNAPSHOTS_DIR"

# Cross-platform sha256
sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    else
        shasum -a 256 | awk '{print $1}'
    fi
}

echo "[sync] fetching $SOURCE_URL"
TMP_RAW="$(mktemp)"
trap 'rm -f "$TMP_RAW" "$TMP_NEW"' EXIT
TMP_NEW="$(mktemp)"

if ! curl --fail --silent --show-error --max-time 60 "$SOURCE_URL" -o "$TMP_RAW"; then
    echo "[sync] fetch failed — leaving existing snapshot untouched" >&2
    exit 1
fi

# Normalize (sorted keys, pretty-printed) so cosmetic ordering changes don't
# create spurious diffs.
jq -S '.' "$TMP_RAW" > "$TMP_NEW"

NEW_HASH="$(sha256 < "$TMP_NEW")"
NEW_HASH_SHORT="${NEW_HASH:0:12}"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

OLD_HASH=""
if [ -f "$OPENAPI_FILE" ]; then
    OLD_HASH="$(sha256 < "$OPENAPI_FILE")"
fi

if [ "$NEW_HASH" = "$OLD_HASH" ]; then
    echo "[sync] no change — hash $NEW_HASH_SHORT"
    exit 0
fi

# Extract a lightweight summary of paths and components for the changelog
NEW_PATHS=$(jq -r '.paths | keys[]' "$TMP_NEW" | sort)
NEW_COMPONENTS=$(jq -r '.components.schemas | keys[]' "$TMP_NEW" | sort)
NEW_API_VERSION=$(jq -r '.info.version // "unknown"' "$TMP_NEW")

# Diff against previous (if any)
DIFF_SUMMARY=""
if [ -n "$OLD_HASH" ] && [ -f "$OPENAPI_FILE" ]; then
    OLD_PATHS=$(jq -r '.paths | keys[]' "$OPENAPI_FILE" | sort)
    OLD_COMPONENTS=$(jq -r '.components.schemas | keys[]' "$OPENAPI_FILE" | sort)

    PATHS_ADDED=$(comm -13 <(echo "$OLD_PATHS") <(echo "$NEW_PATHS") || true)
    PATHS_REMOVED=$(comm -23 <(echo "$OLD_PATHS") <(echo "$NEW_PATHS") || true)
    SCHEMAS_ADDED=$(comm -13 <(echo "$OLD_COMPONENTS") <(echo "$NEW_COMPONENTS") || true)
    SCHEMAS_REMOVED=$(comm -23 <(echo "$OLD_COMPONENTS") <(echo "$NEW_COMPONENTS") || true)

    [ -n "$PATHS_ADDED" ]     && DIFF_SUMMARY+="  + paths added: $(echo "$PATHS_ADDED" | tr '\n' ' ')"$'\n'
    [ -n "$PATHS_REMOVED" ]   && DIFF_SUMMARY+="  - paths removed: $(echo "$PATHS_REMOVED" | tr '\n' ' ')"$'\n'
    [ -n "$SCHEMAS_ADDED" ]   && DIFF_SUMMARY+="  + schemas added: $(echo "$SCHEMAS_ADDED" | tr '\n' ' ')"$'\n'
    [ -n "$SCHEMAS_REMOVED" ] && DIFF_SUMMARY+="  - schemas removed: $(echo "$SCHEMAS_REMOVED" | tr '\n' ' ')"$'\n'
    [ -z "$DIFF_SUMMARY" ]    && DIFF_SUMMARY="  (no path/schema additions or removals — likely field-level edits; see git diff for detail)"$'\n'
else
    DIFF_SUMMARY="  (initial snapshot)"$'\n'
fi

# Move new snapshot into place
cp "$TMP_NEW" "$OPENAPI_FILE"
cp "$TMP_NEW" "$SNAPSHOTS_DIR/${TIMESTAMP}_${NEW_HASH_SHORT}.json"

# Initialize changelog header on first run
if [ ! -f "$CHANGELOG_FILE" ]; then
    cat > "$CHANGELOG_FILE" <<'HEADER'
# OpenAPI snapshot changelog

Internal version log for the seed-mixer API schema. The backend's `info.version`
is unreliable ("0.0.0"), so we track our own snapshots by content hash and
record what changed at the path/schema level.

Latest entry is at the top.

---

HEADER
fi

# Write new entry to a temp file (multi-line awk -v is unreliable on macOS)
NEW_ENTRY_FILE="$(mktemp)"
trap 'rm -f "$TMP_RAW" "$TMP_NEW" "$NEW_ENTRY_FILE"' EXIT

{
    echo ""
    echo "## ${TIMESTAMP} — hash \`${NEW_HASH_SHORT}\` (backend reports v${NEW_API_VERSION})"
    echo ""
    printf '%s' "$DIFF_SUMMARY"
} > "$NEW_ENTRY_FILE"

# Insert the new entry right after the first "---" separator (which closes
# the header block). Resulting file: header + separator + new entry + older entries.
HEADER_END_LINE="$(grep -n '^---$' "$CHANGELOG_FILE" | head -1 | cut -d: -f1)"
if [ -z "$HEADER_END_LINE" ]; then
    echo "[sync] WARN: changelog header malformed, appending instead" >&2
    cat "$NEW_ENTRY_FILE" >> "$CHANGELOG_FILE"
else
    REWRITTEN="$(mktemp)"
    head -n "$HEADER_END_LINE" "$CHANGELOG_FILE" > "$REWRITTEN"
    cat "$NEW_ENTRY_FILE" >> "$REWRITTEN"
    tail -n +"$((HEADER_END_LINE + 1))" "$CHANGELOG_FILE" >> "$REWRITTEN"
    mv "$REWRITTEN" "$CHANGELOG_FILE"
fi

echo "[sync] updated — hash $NEW_HASH_SHORT (was ${OLD_HASH:0:12})"
echo "[sync] changelog: $CHANGELOG_FILE"
echo "[sync] snapshot saved: snapshots/${TIMESTAMP}_${NEW_HASH_SHORT}.json"
