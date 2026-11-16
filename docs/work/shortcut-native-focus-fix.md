# S-050 native shortcut destination correction

Implemented in `/Users/apresley/.t3/worktrees/Please Look Here/t3-57d88448`, branch `t3/shortcut-native-focus`.

## Reported failure and cause

Parent native QA found that Getting Started Practice step 3 opened Shortcuts at scroll position zero, left focus in the sidebar and kept Pen Tool below the viewport. Assignments stayed Unassigned. The old path used `ScrollViewReader.onChange` before the replacement section completed layout, then asked SwiftUI to focus a row wrapper. Recorder buttons also explicitly disabled their native focus ring.

The offscreen regression `recorderHasVisibleNativeFocusWithoutStartingRecording` failed before the fix on `recorder.focusRingType == .exterior`. The original visible practice-link failure was supplied by the parent. No visible window was opened to reproduce it in this worktree.

## Changes

- Pointer, Interact, Pen and radial destinations have stable native control and accessibility identifiers: `settings.shortcut.toggle`, `.mode`, `.pen` and `.radial`.
- SettingsHostingView responds to mounted AppKit layout and SwiftUI request changes. One coalesced main-queue handoff forces completed layout, finds the native control, scrolls it into view and makes it first responder. There are no timed sleeps or retry loops. A destination not mounted yet remains pending for the next layout signal.
- ShortcutRecorder accepts native focus and draws a rounded native focus ring. Focus does not send its action, install recording monitors, invoke registration callbacks or change an assignment. Explicit button activation still starts recording.
- The radial modifier uses a native NSPopUpButton with the same choices, binding, label and Unassigned value. This gives it a stable native destination without depending on SwiftUI's private picker hierarchy.
- Each link retains its fresh request UUID, including repeated links to the same command. A completed request cannot reclaim focus after the person moves to another control. Resize signals reveal the destination only while that control still owns focus; ordinary layout does not undo manual scrolling.
- Ordinary Settings opening, sidebar navigation, section changes, window resignation and closing clear obsolete requests. Deferred work checks the current request, section, key window and application activation before acting. Coalesced work resolves the latest request rather than a captured older destination.
- Per-command conflict text, assignment callbacks, shortcut values, standard editing rules and native sidebar composition remain in their existing paths. Bundle identity, macOS 13 deployment target and Swift 5 language mode are unchanged.
- Added a grid-lint explanation for the pre-existing one-point keycap shadow offset. Its rendering is unchanged.

## Local evidence

All commands ran on Austin's Mac with isolated defaults, Hands and thumbnail paths. Apple Swift 6.4 compiled this package in Swift 5 language mode for `arm64-apple-macos13.0`. No hosted workflow, normal preferences, actual Hands, root untracked assets, GUI automation, visible windows, posted input, installation, signing, notarization or packaging was used.

Focused command:

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit.shortcut-focus-final \
TH_HANDS_DIR=/tmp/tinyhand-shortcut-focus-final/Hands \
TH_THUMBNAILS_DIR=/tmp/tinyhand-shortcut-focus-final/Thumbnails \
swift test --filter 'ShortcutNavigationTests|GettingStartedPracticeTests|ShortcutTests|SettingsAccessibilityTests'
```

22 tests in four suites passed. The six new tests cover native focus without recording or assignment, all four control identities and scrolling, repeated target UUIDs, resize visibility, manual scrolling, focus moved elsewhere, cancelled/superseded/inactive requests and a destination mounted after the request. The real SettingsHostingView is also exercised offscreen, switching General to Shortcuts and navigating Pen, Interact, Pointer, radial and Pen again at heights 640, 440 and 520. Each target becomes first responder and its entire native bounds are visible. Existing tests retain unassigned defaults, explicit legacy assignments, standard editing reservations and per-command conflict behavior.

`swift build -c release --product TinyHand` passed with isolated environment paths. Grid lint passed for GettingStartedPractice, SettingsModel, SettingsView, SettingsWindow, SettingsComponents, PresentationSettings and ShortcutNavigation. `git diff --check` passed.

## Parent acceptance still required

Rebuild the integrated app and check actual visible practice links for Pen, Interact, Pointer and radial, repeated links, navigation after another Settings section and automatic/manual window height changes. Verify native focus cues, Unassigned values, explicit activation to record, ordinary calm Settings opening and cancellation after switching windows or sidebar sections. Offscreen tests prove native responder/scroll behavior and recording safety, not visible active-window appearance or the live Getting Started click route. Parent owns this UI validation and all packaging.

## Glossary and copy proposals

None. Existing command names and user-facing copy remain unchanged.
