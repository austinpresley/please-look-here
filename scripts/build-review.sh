#!/bin/bash
set -euo pipefail
export TINYHAND_APP_NAME="Look Here Please"
export TINYHAND_BUNDLE_ID="com.austinpresley.pleaselookhere.integration"
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
OPEN=false
INSTALL_BUILD=true
for arg in "$@"; do
    case "$arg" in
        --open) OPEN=true ;;
        --package-only) INSTALL_BUILD=false ;;
        *) echo "Usage: $0 [--open] [--package-only]" >&2; exit 2 ;;
    esac
done

IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Austin Robinson (G2R8798RLT)}"
PROFILE="${NOTARY_PROFILE:-look-here-please}"
TEAM="G2R8798RLT"
if [[ "$IDENTITY" != "Developer ID Application: "*" ($TEAM)" ]]; then
    echo "Use Austin's explicit Developer ID Application identity for team $TEAM." >&2
    exit 1
fi
if ! security find-identity -v -p codesigning | /usr/bin/grep -F "\"$IDENTITY\"" | /usr/bin/grep -v CSSMERR >/dev/null; then
    echo "The requested Developer ID identity is unavailable: $IDENTITY" >&2
    exit 1
fi
xcrun notarytool history --keychain-profile "$PROFILE" --output-format json >/dev/null

# Build/validate/notarize the plugin before any app bundle is assembled or signed.
# This leaf script builds only LookHerePleaseDeck; it never calls app packaging.
bash "$ROOT/scripts/build-streamdeck.sh"
python3 "$ROOT/scripts/make-icons.py"
swift build -c release --arch arm64 --arch x86_64 --product TinyHand
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="$ROOT/dist/$APP_NAME.app"
ARCHIVE="$ROOT/dist/$APP_NAME-review.zip"
RECEIPT="$ROOT/dist/review-notarization.json"
INSTALL="$HOME/Applications/$APP_NAME.app"
BASELINE="$INSTALL"
if [[ ! -d "$BASELINE" ]]; then BASELINE="$HOME/Applications/TinyHand Integration.app"; fi
REQUIREMENT=""
if [[ -d "$BASELINE" ]]; then
    codesign --verify --deep --strict "$BASELINE"
    REQUIREMENT="$(codesign -d -r- "$BASELINE" 2>&1 | sed -n 's/^designated => //p')"
    if [[ -z "$REQUIREMENT" ]]; then echo "Cannot read the installed app's identity." >&2; exit 1; fi
fi

make_bundle "$BIN_DIR/$EXECUTABLE_NAME" "$APP" "$(date +%Y%m%d%H%M%S)"
sign_app "$APP" "$IDENTITY" --timestamp
codesign -dv "$APP" 2>&1 | /usr/bin/grep "TeamIdentifier=$TEAM" >/dev/null
if [[ -n "$REQUIREMENT" ]]; then codesign --verify --test-requirement "=$REQUIREMENT" "$APP"; fi

SUBMIT="$ROOT/dist/review-submission.zip"
ditto -c -k --keepParent "$APP" "$SUBMIT"
xcrun notarytool submit "$SUBMIT" --keychain-profile "$PROFILE" --wait --timeout 30m --output-format json > "$RECEIPT"
python3 - "$RECEIPT" <<'PY'
import json, sys
receipt = json.load(open(sys.argv[1]))
if receipt.get('status') != 'Accepted':
    raise SystemExit('Notarization did not return Accepted: ' + str(receipt))
print('Notarization Accepted:', receipt['id'])
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
codesign --verify --deep --strict "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm "$SUBMIT"

# Archive the stapled app, then check the exact bytes that will be delivered.
ditto -c -k --keepParent "$APP" "$ARCHIVE"
unzip -tq "$ARCHIVE"
VERIFY="$(mktemp -d)"
trap 'rm -rf "$VERIFY"' EXIT
ditto -x -k "$ARCHIVE" "$VERIFY"
python3 "$ROOT/scripts/streamdeck-package.py" verify-app "$VERIFY/$APP_NAME.app"
codesign --verify --deep --strict "$VERIFY/$APP_NAME.app"
xcrun stapler validate "$VERIFY/$APP_NAME.app"
spctl --assess --type execute --verbose=2 "$VERIFY/$APP_NAME.app"
shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"

if [[ "$INSTALL_BUILD" == true ]]; then
    mkdir -p "$HOME/Applications"
    STAGED="$HOME/Applications/.$APP_NAME.installing.app"
    PREVIOUS="$HOME/Applications/.$APP_NAME.previous.app"
    rm -rf "$STAGED"
    ditto "$APP" "$STAGED"
    codesign --verify --deep --strict "$STAGED"
    quit_running_app
    rm -rf "$PREVIOUS"
    if [[ -d "$INSTALL" ]]; then mv "$INSTALL" "$PREVIOUS"; fi
    if ! mv "$STAGED" "$INSTALL"; then
        if [[ -d "$PREVIOUS" ]]; then mv "$PREVIOUS" "$INSTALL"; fi
        exit 1
    fi
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$INSTALL"
    codesign --verify --deep --strict "$INSTALL"
    xcrun stapler validate "$INSTALL"
    spctl --assess --type execute --verbose=2 "$INSTALL"
    rm -rf "$PREVIOUS"
    echo "Installed $INSTALL"
    if [[ "$OPEN" == true ]]; then open "$INSTALL"; fi
fi
echo "Review archive: $ARCHIVE"
