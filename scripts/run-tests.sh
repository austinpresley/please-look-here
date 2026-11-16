#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tinyhand-unit.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export TINYHAND_DEFAULTS_SUITE="com.austinpresley.tinyhand.unit.$(uuidgen)"
export TH_HANDS_DIR="$TEST_ROOT/Hands"
export TH_THUMBNAILS_DIR="$TEST_ROOT/Thumbnails"
swift test "$@"
python3 "$ROOT/scripts/test-streamdeck-package.py"
for file in SettingsView SettingsComponents PresentationSettings StreamDeckInstaller RadialMenu MenuBarControls MenuBarCommands; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
for file in HandGestureSettings MagnificationSettings HandMakerSettings SoundSettings PointerLibrary; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
