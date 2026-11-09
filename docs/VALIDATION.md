# Integration review validation

Validated locally on Austin's Mac on 9 November 2026, using macOS 27.0, Apple Silicon and a 1920 × 1080 display. The app remains in the existing Swift 5 language mode. Hosted CI was not created, enabled, dispatched or rerun.

## Results

| Check | Result |
| --- | --- |
| Local unit tests | 24 tests in six suites passed |
| Native input smoke test | 13 checks passed against the disposable public canvas |
| Settings snapshots | Seven pages inspected in Light and Dark, captured from the focused running app |
| Layout probes | All 14 Settings layout files passed |
| Grid lint | SettingsView, SettingsComponents and PresentationSettings passed |
| Review build | Universal arm64 and x86_64 build completed locally |
| Mach-O deployment metadata | Both architectures report macOS minimum 13.0 |
| Bundle signing | Developer ID signature; deep/strict verification passed |
| Pointer discovery | 37 styles discovered; 36 thumbnail files verified |

Xcode 27 emits an x86_64 deprecation warning during universal-build aggregation. The actual binaries' minimum OS is 13.0, checked with `vtool`. There were no Swift source compilation errors. Intel code was cross-built, not run on Intel hardware.

## Selected features and evidence

| Selected rank | Evidence |
| --- | --- |
| 1, normal Point interaction | Real canvas button click, text entry, dragging and native right-click menu observed. Escape dismissed the menu while the pointer remained active. |
| 2, Undo | Unit history tests and native Command-Z / Command-Shift-Z checks, including marker edits. |
| 3, tools | Native pen, rectangle and arrow gestures created annotations. Text editor focused its field; Return added a visible label and Escape canceled without adding an annotation. |
| 5, screenshot | Native capture shortcut and local command produced valid 1920 × 1080 PNGs. Inspected images contained the hand, strokes, rectangle, arrow, marker and text, without the app toolbar. |
| 6, toolbar | Native shortcut hid/revealed it. Global drag moved it and saved its final origin. Position remained consistent through Point/Draw resizing. Reset Position cleared storage and recentered it. |
| 7, markers | Placement, move, click-to-remove, Undo/Redo, and Control-click while Pen remained selected all passed. |
| 8, line controls | Width/opacity captured per annotation in unit tests; native capture showed the configured eight-point, 70% ink. |
| 14, automation | Real private-socket calls exercised status, configuration, style discovery, modes, tools, capture and Settings. Validation and atomic settings batches passed unit tests. |
| 16, keyboard | Native tool, mode, Undo/Redo, capture and toolbar shortcuts passed. UI recorded Pen as P, restored F, and rejected a collision with Control-Option-H. |
| 18, smoothing | Four smoothing cases preserved endpoints; nonzero smoothing reduced jitter in the geometry test. Drawing controls rendered correctly in both appearances. |
| 20, permission recovery | Injected denied access rejected Draw/tool operations while Point remained selectable. Live test instance reported Accessibility and Screen Recording allowed. Actual OS permissions were not revoked for testing. |
| 21, routing | Unit tests covered independent buttons, held modifiers, native controls, stale callbacks and draining captured releases. A real mode change midway through a drag finished with the tap inactive and disabled. |
| 28, motion | Both grip algorithms passed value tests. Native activity reported displayLink for Responsive and timer for Original. UI changed between both selections. Original is the default. |
| 32, appearance/size | Real UI changed Light/Dark; all pages were reviewed in both. Pointer size reached 4% through the native slider decrement action and status acknowledged 0.04. |
| 34, organization/polish | Reviewed General, Shortcuts, Drawing, Pointers, Appearance, Sound and About. Shortcut controls expose their specific labels and assigned values through Accessibility. |

## Snapshot review

Files are under `dist/verification`. General fits its permission, mode and capture controls. Drawing keeps tools, width, opacity and ink settings aligned. Appearance shows the live Original/Responsive selection. Pointers retains the existing gallery and custom-hand entry point. Sound choices and About remain readable. No unexpected focus rings or overlapping content appeared in Settings. Shortcuts intentionally scrolls; its bottom Number and Undo/Redo rows were separately inspected.

The older standalone Settings snapshot entry point produced inactive windows during the first pass. Those images were replaced. The accepted snapshot helper rejects capture unless Settings is visible, key and its application active.

## Reproduce

Run `bash scripts/run-tests.sh` and `bash scripts/build-review.sh` locally.

For UI evidence, start the project bundle's executable with TINYHAND_TEST_MODE=1, APP_SNAPSHOT pointing at `dist/verification`, TINYHAND_DEFAULTS_SUITE set to a test suite, and TH_HANDS_DIR set to a temporary folder. Focus its Settings window and run `python3 scripts/snapshot-settings.py`.

Build the disposable canvas with `bash scripts/build-fixture.sh`. Only run `python3 scripts/live-smoke.py` while that public fixture is visible. The probe uses native system events and guards fixture presence, coordinates and keyboard focus. The normal app does not expose the snapshot operation. Native smoke results are in `dist/verification/live-smoke.json`.

## Review-build limits

This is a signed local review build, without notarization or a release update feed. The verified running instance is the project copy under `dist/TinyHand Integration.app`. A direct command-line launch of the copied `~/Applications` bundle stalled in dyld on this Mac; that path is not claimed as a verified launcher. macOS assessment reports an unnotarized Developer ID build. Public release/notarization is deferred.

Runtime checks covered this Mac and display. Older macOS versions, Intel hardware, multiple physical displays and a forced system-permission revocation remain manual checks. macOS 13 uses the timer fallback for Responsive and a bounded one-frame screenshot stream. The review app has separate preferences and a separate custom-hand folder from upstream TinyHand.

ScreenCaptureKit sizing uses the filter's screen-point content rectangle and pixel scale, following [Apple's contentRect documentation](https://developer.apple.com/documentation/screencapturekit/sccontentfilter/contentrect).
