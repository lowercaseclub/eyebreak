#!/bin/bash
#
# build.sh — Compile EyeBreak and assemble .app bundle + DMG
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/EyeBreak.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
FRAMEWORKS="$CONTENTS/Frameworks"
BINARY="$MACOS/EyeBreak"

VERSION="1.1.1"
SPARKLE_VERSION="2.8.0"
SPARKLE_DIR="$SCRIPT_DIR/deps/Sparkle"
APPCAST_URL="https://lowercaseclub.github.io/eyebreak/appcast.xml"

# --- Legacy cleanup (only with --cleanup flag) ---
if [[ "${1:-}" == "--cleanup" ]]; then
    echo "Cleaning up old launchd agents and scripts..."
    launchctl bootout "gui/$(id -u)/com.user.eyebreak" 2>/dev/null || true
    launchctl bootout "gui/$(id -u)/com.user.nightshift" 2>/dev/null || true
    rm -f ~/Library/LaunchAgents/com.user.eyebreak.plist
    rm -f ~/Library/LaunchAgents/com.user.nightshift.plist
    rm -f ~/scripts/eye-break.sh ~/scripts/night-shift.sh ~/scripts/EyeBreak ~/scripts/MeetingDetect
    echo "Cleanup complete."
    exit 0
fi

echo "=== Building EyeBreak.app (v${VERSION}) ==="

# --- Download Sparkle if not cached ---
if [ ! -d "$SPARKLE_DIR" ]; then
    echo "Downloading Sparkle ${SPARKLE_VERSION}..."
    mkdir -p "$SPARKLE_DIR"
    SPARKLE_TAR="$SPARKLE_DIR/Sparkle-${SPARKLE_VERSION}.tar.xz"
    curl -L -o "$SPARKLE_TAR" \
        "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz"
    tar -xf "$SPARKLE_TAR" -C "$SPARKLE_DIR"
    rm "$SPARKLE_TAR"
    echo "Sparkle extracted to $SPARKLE_DIR"
fi

# Verify Sparkle framework exists
if [ ! -d "$SPARKLE_DIR/Sparkle.framework" ]; then
    echo "ERROR: Sparkle.framework not found in $SPARKLE_DIR"
    exit 1
fi

# Clean previous build
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$FRAMEWORKS"

# --- Compile ---
echo "Compiling..."
swiftc "$SCRIPT_DIR"/src/*.swift -o "$BINARY" \
    -framework AppKit \
    -framework CoreAudio \
    -framework CoreMediaIO \
    -framework ServiceManagement \
    -F "$SPARKLE_DIR" \
    -framework Sparkle \
    -Xlinker -rpath -Xlinker @loader_path/../Frameworks

echo "Binary compiled: $BINARY"

# --- Copy Sparkle.framework into app bundle ---
echo "Embedding Sparkle.framework..."
cp -a "$SPARKLE_DIR/Sparkle.framework" "$FRAMEWORKS/"

# --- Copy app icon ---
RESOURCES="$CONTENTS/Resources"
mkdir -p "$RESOURCES"
cp "$SCRIPT_DIR/assets/AppIcon.icns" "$RESOURCES/"

# --- Write Info.plist ---
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>EyeBreak</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.eyebreak</string>
    <key>CFBundleName</key>
    <string>EyeBreak</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${APPCAST_URL}</string>
    <key>SUPublicEDKey</key>
    <string>YAhSP9JH/+bBp46nvO3NGsibEtyCVHWVBz21DW2Tn48=</string>
</dict>
</plist>
PLIST

echo "Info.plist written"

# --- Codesign app bundle (ad-hoc) ---
echo "Codesigning (ad-hoc)..."
codesign --force --deep -s - "$APP_DIR"

# --- Create styled DMG ---
echo "Creating styled DMG..."
STAGING="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -a "$APP_DIR" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

DMG_PATH="$BUILD_DIR/EyeBreak.dmg"
DMG_RW="$BUILD_DIR/EyeBreak_rw.dmg"
rm -f "$DMG_PATH" "$DMG_RW"

# Detach any existing EyeBreak volumes to avoid conflicts
for dev in $(hdiutil info | grep '/Volumes/EyeBreak' | awk '{print $1}' || true); do
    hdiutil detach "$dev" 2>/dev/null || true
done

# Create read-write DMG
hdiutil create "$DMG_RW" -volname "EyeBreak" -srcfolder "$STAGING" -ov -format UDRW -quiet

# Mount it and capture mount point
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify "$DMG_RW")
DEVICE=$(echo "$MOUNT_OUTPUT" | grep '/Volumes/' | awk '{print $1}')
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep '/Volumes/' | sed 's/.*\(\/Volumes\/.*\)/\1/' | xargs)

# Add background image
mkdir -p "$MOUNT_POINT/.background"
cp "$SCRIPT_DIR/assets/dmg-background.png" "$MOUNT_POINT/.background/background.png"

# Style with AppleScript
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "EyeBreak"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 700, 500}
        set opts to icon view options of container window
        set icon size of opts to 128
        set arrangement of opts to not arranged
        set background picture of opts to file ".background:background.png"
        set position of item "EyeBreak.app" to {150, 190}
        set position of item "Applications" to {450, 190}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Finalize — convert to compressed read-only DMG
sync
hdiutil detach "$DEVICE" -quiet
hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_PATH" -quiet
rm -f "$DMG_RW"
rm -rf "$STAGING"
echo "DMG created: $DMG_PATH"

echo ""
echo "=== Build complete ==="
echo "  App: $APP_DIR"
echo "  DMG: $DMG_PATH"
echo ""
echo "Run:     open $APP_DIR"
echo "Install: open $DMG_PATH"
