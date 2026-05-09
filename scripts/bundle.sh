#!/bin/bash
# Bundle the SwiftPM-built binary into a macOS .app.
# No Xcode required — uses only `swift build`, `plutil`, and `codesign`.
#
# Why bundle: a bare SwiftPM executable has no Info.plist and no stable
# bundle identifier, which means LSUIElement (hide from Dock) doesn't
# stick and we can't be a well-behaved menu-bar app. Wrapping in a .app
# gives us LSUIElement + a real bundle identity.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
APP_NAME="Hoist"
BUNDLE_ID="com.hoist.Hoist"
APP_DIR="$ROOT/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RES_DIR="$CONTENTS/Resources"
CONFIG="${1:-release}"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG"

BIN="$ROOT/.build/$CONFIG/$APP_NAME"
if [ ! -f "$BIN" ]; then
  echo "Error: expected binary at $BIN" >&2
  exit 1
fi

echo "==> Assembling $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$BIN" "$MACOS_DIR/$APP_NAME"

# App icon. Built ahead of time via `iconutil` from
# /Users/anshul/Downloads/hoist-icons/png/app-geometric-light/. Lives in
# Resources/ so the build is reproducible without network access.
ICNS="$ROOT/Resources/Hoist.icns"
if [ -f "$ICNS" ]; then
  cp "$ICNS" "$RES_DIR/Hoist.icns"
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>Hoist</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Info.plist" > /dev/null

echo "==> Ad-hoc signing"
codesign --force --deep --sign - --entitlements /dev/null "$APP_DIR" 2>/dev/null \
  || codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "Built: $APP_DIR"
echo "Launch: open \"$APP_DIR\""
