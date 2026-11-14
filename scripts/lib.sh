#!/bin/bash

APP_NAME="${TINYHAND_APP_NAME:-Look Here Please}"
EXECUTABLE_NAME="TinyHand"
BUNDLE_ID="${TINYHAND_BUNDLE_ID:-com.austinpresley.pleaselookhere.integration}"
REPO="${LOOK_HERE_PLEASE_UPDATE_REPO:-}"
FEED_URL="${LOOK_HERE_PLEASE_UPDATE_FEED:-}"
SPARKLE_PUBLIC_KEY="${LOOK_HERE_PLEASE_UPDATE_PUBLIC_KEY:-}"
SPARKLE_VERSION="2.10.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${TINYHAND_VERSION:-$(tr -d '[:space:]' < "$ROOT/VERSION")}"

quit_running_app() {
    osascript -e "if application id \"$BUNDLE_ID\" is running then tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
}

make_bundle() {
    local binary="$1" app="$2" build="$3" updates="${4:-}"
    local update_keys=""
    if [[ "$updates" == "--with-updates" ]]; then
        if [[ -z "$FEED_URL" || -z "$SPARKLE_PUBLIC_KEY" || "$FEED_URL" == *nilbuild/tinyhand* ]]; then
            echo "Configure a Look Here Please update feed and public key before packaging updates." >&2
            return 1
        fi
        update_keys="    <key>SUFeedURL</key>
    <string>$FEED_URL</string>
    <key>SUPublicEDKey</key>
    <string>$SPARKLE_PUBLIC_KEY</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>"
    fi
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$binary" "$app/Contents/MacOS/$EXECUTABLE_NAME"
    cp "$ROOT"/assets/hand_*.png "$app/Contents/Resources/"
    cp "$ROOT"/assets/gesture_*.png "$app/Contents/Resources/"
    cp "$ROOT"/assets/sounds/tap_*.wav "$ROOT/assets/AppIcon.icns" "$ROOT/assets/Assets.car" "$app/Contents/Resources/"
    cp "$ROOT"/assets/menubar_*.png "$app/Contents/Resources/"
    cp "$ROOT/assets/LookHerePlease.sdef" "$app/Contents/Resources/"
    cp "$ROOT/LICENSE" "$app/Contents/Resources/LICENSE.txt"
    cp "$ROOT/assets/ThirdPartyNotices.txt" "$app/Contents/Resources/ThirdPartyNotices.txt"

    local fw
    fw="$(find "$ROOT/.build/artifacts" -path "*macos-arm64_x86_64/Sparkle.framework" -maxdepth 6 | head -1)"
    mkdir -p "$app/Contents/Frameworks"
    ditto "$fw" "$app/Contents/Frameworks/Sparkle.framework"

    cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>TinyHandControlVersion</key>
    <integer>1</integer>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>OSAScriptingDefinition</key>
    <string>LookHerePlease.sdef</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$build</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHumanReadableCopyright</key>
    <string>© $(date +%Y) Austin Presley. Based on TinyHand by Kamran Ahmed. MIT License.</string>
$update_keys
</dict>
</plist>
PLIST
    # Fail closed for missing, changed or stale plugin inputs. Never use a dev path at runtime.
    python3 "$ROOT/scripts/streamdeck-package.py" embed "$app" "$ROOT/dist/streamdeck"
}

sign_app() {
    local app="$1" identity="$2" ts="${3:-}"
    local fw="$app/Contents/Frameworks/Sparkle.framework/Versions/B"
    local sign=(codesign --force --options runtime --sign "$identity")
    [[ -n "$ts" ]] && sign+=(--timestamp)
    "${sign[@]}" "$fw/XPCServices/Installer.xpc"
    "${sign[@]}" --preserve-metadata=entitlements "$fw/XPCServices/Downloader.xpc"
    "${sign[@]}" "$fw/Autoupdate"
    "${sign[@]}" "$fw/Updater.app"
    "${sign[@]}" "$app/Contents/Frameworks/Sparkle.framework"
    "${sign[@]}" "$app"
    codesign --verify --deep --strict "$app"
}

sparkle_tools() {
    local dir="$ROOT/.build/sparkle-tools-$SPARKLE_VERSION"
    if [[ ! -x "$dir/bin/sign_update" ]]; then
        mkdir -p "$dir"
        curl -fsSL "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz" \
            | tar -xJ -C "$dir"
    fi
    echo "$dir/bin"
}
