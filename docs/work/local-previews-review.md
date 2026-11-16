# Local previews implementation

## S-041 drawing preview

UX: Drawing opens one inline Practice drawing canvas above Stroke and Ink. The sample redraws while width, opacity, smoothing, color and lifetime values change. Replay Sample restarts it on demand. The local Interact/Draw picker controls only this canvas. Clear and Undo act only on practice ink. Text has a local text field; the other tools use direct canvas gestures. Escape cancels the current local gesture. Tool instructions moved into concise contextual help on the selected-tool picker.

The lifetime label explicitly says "Keep until cleared. The sample stays here." for permanent ink. Samples show a complete line immediately, including during continuous slider drags, then use the real InkLifetimePolicy and InkVisibility behavior. Trail samples erase along the path; shape and text practice obey whole-object expiry. Expiry never edits semantic geometry/history.

### Reusable practice API

- Construct `DrawingPracticeConfiguration` with independent tool, color, width, opacity, smoothing and lifetime values. `.current` is a read-only Settings adapter. The canvas and session never write Preferences.
- Construct `DrawingPracticeSession(configuration:clock:)`. It owns its own `Ink`, policy holder, local mode and text. The Ink clock can be injected for deterministic lifetime tests.
- Embed `DrawingPracticeCanvas(session:configuration:replay:)` in a future onboarding/practice window. Supply a caller-owned session and values; increment `replay` to restart the sample. No overlay, Accessibility grant, InputTap, shared annotation document or global event monitor is needed.
- `configure` returns whether values changed. The host restarts the sample on a change or resize. Each replay resets only local history, avoiding unbounded demo history. Ordinary practice keeps semantic history for local Undo. `clear` resets local history; dismantling the view clears the disposable session and stops its Ink visibility clock.
- `mode` is local Interact/Draw, unrelated to Preferences.pointerMode. `begin`, `extend`, `end` and `cancel` allow independent native input hosts. Practice Text uses `session.text` and never opens the live text editor.

### Snapshot and layout handoff

Changed snapshots: Drawing in Light and Dark, all three fading choices, Text practice, Eraser/Highlighter practice, narrow Settings width. New layout area `drawingPreview` probes controls, canvas bounds, optional text field, lifetime label and help. Parent owns native snapshots, keyboard/VoiceOver checks, active-window appearance and `check-layout.swift` certification. No UI automation, install, signing, packaging or snapshots run in this worktree.

### Copy/glossary proposals

- Practice drawing: a disposable canvas in Settings with separate ink and history.
- Replay Sample: restart only the practice sample with current Drawing values.
- Practice mode: local Interact/Draw, without changing the desktop mode.

### Local evidence

Passed `DrawingPracticeTests`: 4 tests, including both timed-fade cases. Covered preference/live-history isolation, style updates, complete semantic geometry after expiry, restarted timed samples, permanent samples, Interact cancellation, text, highlighter and eraser practice. The executable and focused test target compiled locally with no compiler warnings. `scripts/grid-lint.sh` passed DrawingPreview.swift, DrawingPractice.swift and PresentationSettings.swift. Swift 5 language mode and macOS 13 deployment remain unchanged.

The repository-wide test target currently cannot compile because PointerCatalogTests.swift:229 calls throwing `CustomHands.remove` in a defer without handling the error. Left that unrelated file untouched. Ran focused tests using a disposable SwiftPM manifest in `/tmp` with symlinked worktree Sources/Tests and a test target whose explicit sources list contains only DrawingPracticeTests.swift. Isolated environment: `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit.previews.87031b3e`, `TH_HANDS_DIR=/tmp/lhp-local-previews-87031b3e/Hands` and `TH_THUMBNAILS_DIR=/tmp/lhp-local-previews-87031b3e/Thumbnails`. No normal persistent preference domain or real Hands were written.
