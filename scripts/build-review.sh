#!/bin/bash
set -euo pipefail
export TINYHAND_APP_NAME="TinyHand Integration"
export TINYHAND_BUNDLE_ID="com.austinpresley.pleaselookhere.integration"
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP="$ROOT/dist/$APP_NAME.app"
quit_running_app
make_bundle "$BIN_DIR/$EXECUTABLE_NAME" "$APP" "$(date +%Y%m%d%H%M)"
IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Developer ID Application:/ {print $2; exit}')}"
if [[ -z "$IDENTITY" ]]; then IDENTITY="-"; fi
sign_app "$APP" "$IDENTITY"
INSTALL="$HOME/Applications/$APP_NAME.app"
mkdir -p "$HOME/Applications"
quit_running_app
# Replace the complete signed bundle rather than mixing old and new resources.
rm -rf "$INSTALL"
ditto "$APP" "$INSTALL"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R -trusted "$INSTALL"
echo "Installed $INSTALL"
echo "Local review build; no update feed is included."
if [[ "${1:-}" == "--open" ]]; then
    "$APP/Contents/MacOS/$EXECUTABLE_NAME" > "$ROOT/dist/review-run.log" 2>&1 &
fi
