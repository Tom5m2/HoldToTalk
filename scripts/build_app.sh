#!/bin/bash
# Builds build/HoldToTalk.app (universal: Apple Silicon + Intel) and build/HoldToTalk.zip
# Usage: scripts/build_app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
VERSION="${VERSION#v}"
APP="build/HoldToTalk.app"

rm -rf build/HoldToTalk.app build/HoldToTalk.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swift build -c release --arch arm64
swift build -c release --arch x86_64
lipo -create \
  .build/arm64-apple-macosx/release/HoldToTalk \
  .build/x86_64-apple-macosx/release/HoldToTalk \
  -output "$APP/Contents/MacOS/HoldToTalk"

sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# Ad-hoc signature (no paid Apple Developer account needed).
codesign --force --deep --sign - "$APP"

ditto -c -k --keepParent "$APP" build/HoldToTalk.zip
echo "Built $APP and build/HoldToTalk.zip (version $VERSION)"
