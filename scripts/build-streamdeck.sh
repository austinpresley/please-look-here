#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PLUGIN_ID="com.austinpresley.lookhereplease"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Austin Robinson (G2R8798RLT)}"
PROFILE="${NOTARY_PROFILE:-look-here-please}"
OUTPUT="$ROOT/dist/streamdeck"
BUNDLE="$OUTPUT/$PLUGIN_ID.sdPlugin"
ARCHIVE="$OUTPUT/$PLUGIN_ID.streamDeckPlugin"
RECEIPT="$OUTPUT/notarization.json"

if [[ "$IDENTITY" != "Developer ID Application: "*" (G2R8798RLT)" ]]; then
    echo "Use Austin's explicit Developer ID Application identity for team G2R8798RLT." >&2
    exit 1
fi
if ! security find-identity -v -p codesigning | /usr/bin/grep -F "\"$IDENTITY\"" | /usr/bin/grep -qv CSSMERR; then
    echo "The requested Developer ID identity is unavailable: $IDENTITY" >&2
    exit 1
fi
xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null

swift build -c release --arch arm64 --arch x86_64 --product LookHerePleaseDeck
BINARY="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/LookHerePleaseDeck"

rm -rf "$OUTPUT"
mkdir -p "$BUNDLE"
cp "$ROOT/streamdeck/manifest.json" "$BUNDLE/"
cp -R "$ROOT/streamdeck/inspectors" "$BUNDLE/inspectors"
cp "$ROOT/LICENSE" "$BUNDLE/LICENSE"
cp "$BINARY" "$BUNDLE/look-here-please-deck"
chmod 755 "$BUNDLE/look-here-please-deck"
"$BUNDLE/look-here-please-deck" --render-assets "$BUNDLE/icons"
# Brand only the plugin/category identity. Action and observed key artwork stay app-owned.
cp "$ROOT"/streamdeck/branding/*.png "$BUNDLE/icons/"
codesign --force --options runtime --timestamp --identifier "$PLUGIN_ID" --sign "$IDENTITY" "$BUNDLE/look-here-please-deck"
codesign --verify --strict "$BUNDLE/look-here-please-deck"

npx --yes @elgato/cli@1.10.0 validate "$BUNDLE" --force-update-check

# ditto keeps the executable bit, which Stream Deck needs to launch the plugin.
(cd "$OUTPUT" && ditto -c -k --keepParent "$PLUGIN_ID.sdPlugin" "$ARCHIVE")
unzip -tq "$ARCHIVE"
SUBMIT="$OUTPUT/notarization.zip"
cp "$ARCHIVE" "$SUBMIT"
xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait --timeout 30m --output-format json > "$RECEIPT"
rm "$SUBMIT"
python3 - "$RECEIPT" <<'PY'
import json, sys
receipt = json.load(open(sys.argv[1]))
if receipt.get('status') != 'Accepted':
    raise SystemExit('Notarization did not return Accepted: ' + str(receipt))
print('Notarization Accepted:', receipt['id'])
PY
unzip -Z "$ARCHIVE" "$PLUGIN_ID.sdPlugin/look-here-please-deck" | /usr/bin/grep -q -- '-rwx'
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
python3 "$ROOT/scripts/streamdeck-package.py" record "$OUTPUT"
echo "Stream Deck plugin: $ARCHIVE"
