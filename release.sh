#!/bin/bash
#
# release.sh — Build, sign, and publish an EyeBreak release
#
# Usage: ./release.sh 1.2
#
set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "  e.g. $0 1.2"
    exit 1
fi

NEW_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
DMG_PATH="$BUILD_DIR/EyeBreak.dmg"
APPCAST="$SCRIPT_DIR/docs/appcast.xml"
SIGN_TOOL="$SCRIPT_DIR/deps/Sparkle/bin/sign_update"
REPO="lowercaseclub/eyebreak"

echo "=== Releasing EyeBreak v${NEW_VERSION} ==="

# 1. Update VERSION in build.sh
echo "Updating version to ${NEW_VERSION}..."
sed -i '' "s/^VERSION=\".*\"/VERSION=\"${NEW_VERSION}\"/" "$SCRIPT_DIR/build.sh"

# 2. Build
echo "Building..."
"$SCRIPT_DIR/build.sh"

# 3. Verify outputs
if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG not found at $DMG_PATH"
    exit 1
fi

# 4. Sign DMG with Sparkle EdDSA key
echo "Signing DMG..."
if [ ! -x "$SIGN_TOOL" ]; then
    echo "ERROR: sign_update not found at $SIGN_TOOL"
    echo "Run: deps/Sparkle/bin/generate_keys (one-time setup)"
    exit 1
fi

SIGNATURE=$("$SIGN_TOOL" "$DMG_PATH")
# sign_update outputs: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"')
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"')

DMG_SIZE=$(stat -f%z "$DMG_PATH")
PUB_DATE=$(date -R)
DMG_URL="https://github.com/${REPO}/releases/download/v${NEW_VERSION}/EyeBreak.dmg"

# 5. Update appcast.xml
echo "Updating appcast.xml..."
ITEM_TMP=$(mktemp)
cat > "$ITEM_TMP" <<ITEM_EOF
        <item>
            <title>Version ${NEW_VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure
                url="${DMG_URL}"
                ${ED_SIGNATURE}
                ${LENGTH}
                type="application/octet-stream"
                sparkle:version="${NEW_VERSION}"
                sparkle:shortVersionString="${NEW_VERSION}"
            />
        </item>
ITEM_EOF

# Insert new item after </language> line
sed -i '' "/<\/language>/r ${ITEM_TMP}" "$APPCAST"
rm "$ITEM_TMP"

# 6. Commit and tag
echo "Committing..."
git add "$SCRIPT_DIR/build.sh" "$APPCAST"
git commit -m "Release v${NEW_VERSION}"
git tag "v${NEW_VERSION}"

# 7. Push
echo "Pushing..."
git push origin main
git push origin "v${NEW_VERSION}"

# 8. Create GitHub Release
echo "Creating GitHub Release..."
gh release create "v${NEW_VERSION}" "$DMG_PATH" \
    --repo "$REPO" \
    --title "EyeBreak v${NEW_VERSION}" \
    --notes "EyeBreak v${NEW_VERSION}"

echo ""
echo "=== Release v${NEW_VERSION} complete ==="
echo "  GitHub: https://github.com/${REPO}/releases/tag/v${NEW_VERSION}"
echo "  Appcast: https://lowercaseclub.github.io/eyebreak/appcast.xml"
