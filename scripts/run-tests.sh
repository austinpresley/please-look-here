#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tinyhand-unit.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export TINYHAND_DEFAULTS_SUITE="com.austinpresley.tinyhand.unit.$(uuidgen)"
export TH_HANDS_DIR="$TEST_ROOT/Hands"
export TH_THUMBNAILS_DIR="$TEST_ROOT/Thumbnails"
# Suites share the disposable defaults domain and main-queue AppKit fixtures.
# Serialize across suites too, so asynchronous fixtures cannot change another
# suite's presentation mode while its permission assertions are running.
swift test --no-parallel "$@"
python3 "$ROOT/scripts/test-streamdeck-package.py"
for file in SettingsView SettingsComponents PresentationSettings StreamDeckInstaller RadialMenu RadialRenderer RadialLayout RadialAccessibility QuickControlsList RadialArtwork PointerBrowser ClearRecovery QuickCommandError MenuBarControls MenuBarCommands PresentationControls UsabilityVerification Toolbar WelcomeWindow GettingStartedPracticeWindow; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
for file in DrawingPreview PresetsSettings SuggestedShortcuts SettingsNavigation SettingsPages ShortcutsSettings PointerSettingsSheets PointersSettingsPage PointerInspector PointerCustomization UsabilityGlyph MagnificationSettings HandMakerSettings SoundSettings PointerLibrary; do "$ROOT/scripts/grid-lint.sh" "$ROOT/Sources/TinyHand/$file.swift"; done
