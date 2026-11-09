#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/verification/TinyHandFixture.app"
mkdir -p "$APP/Contents/MacOS"
swiftc "$ROOT/Tests/Fixtures/Canvas.swift" -o "$APP/Contents/MacOS/TinyHandFixture" -framework AppKit
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.austinpresley.tinyhand.fixture</string>
<key>CFBundleName</key><string>TinyHandFixture</string>
<key>CFBundleExecutable</key><string>TinyHandFixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP"
echo "$APP"
