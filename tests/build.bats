#!/usr/bin/env bats

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # Build the app
    run "$SCRIPT_DIR/build.sh"
    [ "$status" -eq 0 ]
}

teardown() {
    rm -rf "$SCRIPT_DIR/build"
}

@test "build.sh produces EyeBreak.app" {
    [ -d "$SCRIPT_DIR/build/EyeBreak.app" ]
}

@test "binary exists and is executable" {
    [ -x "$SCRIPT_DIR/build/EyeBreak.app/Contents/MacOS/EyeBreak" ]
}

@test "Info.plist contains LSUIElement" {
    grep -q "LSUIElement" "$SCRIPT_DIR/build/EyeBreak.app/Contents/Info.plist"
}

@test "Info.plist has correct bundle identifier" {
    grep -q "com.user.eyebreak" "$SCRIPT_DIR/build/EyeBreak.app/Contents/Info.plist"
}

@test "Info.plist has minimum system version 13.0" {
    grep -q "13.0" "$SCRIPT_DIR/build/EyeBreak.app/Contents/Info.plist"
}

@test "Info.plist contains SUFeedURL" {
    grep -q "SUFeedURL" "$SCRIPT_DIR/build/EyeBreak.app/Contents/Info.plist"
}

@test "Sparkle.framework is embedded in app bundle" {
    [ -d "$SCRIPT_DIR/build/EyeBreak.app/Contents/Frameworks/Sparkle.framework" ]
}

@test "build.sh produces EyeBreak.dmg" {
    [ -f "$SCRIPT_DIR/build/EyeBreak.dmg" ]
}
