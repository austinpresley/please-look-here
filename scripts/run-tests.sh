#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit TH_HANDS_DIR=/tmp/tinyhand-unit-hands swift test
for file in SettingsView SettingsComponents PresentationSettings; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
