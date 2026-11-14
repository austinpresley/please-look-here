#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit TH_HANDS_DIR=/tmp/tinyhand-unit-hands swift test
python3 "$ROOT/scripts/test-streamdeck-package.py"
for file in SettingsView SettingsComponents PresentationSettings StreamDeckInstaller RadialMenu MenuBarControls MenuBarCommands; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
for file in HandGestureSettings MagnificationSettings HandMakerSettings SoundSettings PointerLibrary; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
