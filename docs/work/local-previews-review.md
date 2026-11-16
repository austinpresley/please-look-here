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

## S-047 pointer preview

UX: Appearance has an inline Pointer preview with a native Light/Dark/Patterned background picker and explicit Preview Tap and Preview Motion buttons. Moving or clicking inside the sample affects only the sample. The current selected pointer uses effective size and applicable shadow values, plus the shared follow behavior and tap swing. Reduce Motion disables decorative motion playback and the real renderer suppresses tap swing. The local canvas handles Escape, pointer exit and teardown cancellation. No sound plays from the visual preview.

`PointerPreviewConfiguration` is a transient value snapshot for rendering, with no persistence or inheritance rules of its own. Its read-only `.current` adapter calls S-042's `Preferences.pointerConfiguration(for:)`. `PointerPreviewPlayback` owns bounded local travel and tap timing. `PointerPreviewView` owns one independent ArmView and a timer that sleeps when playback and settling stop. It never creates OverlayController, starts an InputTap, posts native events, saves a preference or touches a live annotation document.

ArmView's additive `init(frame:previewConfiguration:)` and `applyPreviewConfiguration` share the existing hand/laser/spotlight/presentation rendering, follow and tap implementation. Normal construction still subscribes to effective preference changes. Preview construction receives explicit values and has no preferences observer. Style changes retain the explicit local values. A 720 pt reference height makes hand sizes and contact shadows readable in the compact sample; laser size also scales locally without the desktop's four-point minimum. The live rendering path keeps its existing dimensions and minimum.

### Integration dependency

S-047 depends on the other agent's S-042 commit `89031196231f221fabfdcf3fd1b03c2c93368c96`. It was cherry-picked into this isolated branch as `6263e8bcbf7833d1c4e68784ab8dbb9a9ebb2c15` to compile and test the real effective-value adapter. The dependency conflict in ControlBridge preserved both `item["configuration"]` and S-044's cached thumbnail export. The authored S-047 commit touches only ArmView, PresentationSettings, the two PointerPreview modules, its own tests and this note.

Parent integration order: S-041, S-042 from its owner, then S-047. If S-042 is already integrated, do not cherry-pick this branch's dependency copy. Keep the native PointerCustomization view and its existing override model. The merged ArmView `updatePointerConfiguration` chooses explicit preview values only for preview instances and otherwise uses the S-042 effective API. The display annotation store remains intact.

### Snapshot and layout handoff

Changed snapshots: Appearance in Light and Dark; all three sample backgrounds; built-in and custom hands; Original and Contact shadows; Laser, Spotlight and Presentation pointer; minimum and maximum size; Original/Responsive follow; tap swing off/on and Reduce Motion. New `pointerPreview` area probes the native controls row, canvas bounds and help. Parent must certify layout and actual keyboard/VoiceOver behavior, including sample visibility while adjusting controls at constrained screen heights. The existing Settings scroll/window sizing is retained. No native screenshots or visual layout certification are claimed here.

Copy/glossary proposals: Pointer preview is a local sample of the selected pointer. Sample background names only the preview background. Preview Tap and Preview Motion act on the sample without activating the desktop pointer.

### Local evidence

- Final local preview run passed 10 tests across DrawingPracticeTests and PointerPreviewTests. Pointer coverage includes effective override readback, no persistent-domain writes, no live-ink mutations, local bounds hit-testing, timed playback completion/cancellation, Reduce Motion and explicit local renderer sizing that stays independent of preference notifications. Both executable targets and focused tests compiled locally with no compiler warnings.
- S-042 PointerConfigurationTests passed all 8 tests in a separate isolated suite named `com.austinpresley.tinyhand.unit.pointer-defaults-previews.87031b3e`.
- The two pure thumbnail-cache tests passed: unchanged exports are reused and altered/deleted exports reuse encoded bytes without following symlinks.
- Grid lint passed DrawingPractice.swift, DrawingPreview.swift, PointerPreview.swift, PointerPreviewPlayback.swift and PresentationSettings.swift. `git diff --check` passed. Actual layout-probe output awaits parent snapshots.
- Disposable manifest used symlinked worktree Sources/Tests and explicit selected test sources. Final focused command was `swift test --package-path <temporary-manifest> --scratch-path .build-local-previews-focused --filter 'DrawingPracticeTests|PointerPreviewTests'`, with the isolated suite/Hands/Thumbnails environment listed above. Logs are `/tmp/lhp-preview-final-test.log`, `/tmp/lhp-preview-config-test.log` and `/tmp/lhp-preview-thumbnail-test.log`.
- An earlier expanded run included the full thumbnail suite. Its fixture assumptions failed under the disposable manifest: no linked artwork, missing thumbnail parent output and working-directory alias handling. The configuration suite also requires `pointer-defaults` in its suite name. No unrelated source/tests were changed; the relevant configuration and pure-cache cases were rerun separately with their correct prerequisites. The original repository-wide PointerCatalogTests compile blocker remains outside this task.

No hosted CI, UI automation, install, packaging, signing, notarization, PR, push or delivery ran. Normal preferences, real Hands and existing root untracked artwork were preserved.
