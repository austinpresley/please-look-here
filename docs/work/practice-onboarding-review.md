# S-050 getting started practice

Recommendation 15 is implemented in this worktree. Native UI acceptance belongs to the parent after integration. Swift 5 language mode and macOS 13 support are unchanged.

## UX and entry points

Welcome's existing Show Pointer and drawing-permission actions keep their behavior. A separate Try Getting Started Practice button opens a disposable window. Existing users can open Getting Started Practice from More Commands or Settings > General > Getting started > Try It. Shortcuts > Quick controls also has Try It, opening the radial lesson directly. Opening practice never marks onboarding complete, assigns a shortcut, activates the desktop pointer or asks for permission.

The window has four short steps: Pointer On, Interact, drawing, and radial hold/move/release. Back, Next, Replay Step, Start Again and Done provide a complete return path. No exercise gates Next. Step-local values reset on replay. Closing discards all local ink and preview views. Escape cancels an active local stroke or radial selection; window focus loss cancels local input and pointer playback. App text fields retain native editing behavior.

The pointer step uses the current pointer's explicit preview configuration. The drawing steps use a fixed permanent purple Pen sample so practice is readable regardless of the user's tool or ink lifetime. Interact switches only the practice session. Try This Button counts local clicks with Interact on. Interact off enables the independent drawing canvas. Annotation count, Undo and Clear give visible feedback. The existing reusable drawing canvas starts with its sample line.

The radial step teaches one category in the real Tools direction. Press and hold its center, drag right through Tools, move outward to Pen, Rectangle or Arrow, and release. Returning to the center, Escape, step changes and focus loss cancel. It reuses RadialSession's actual category, candidate and backtracking rules. Native Hold Menu, Move to Tools, Move to Pen, Release and Cancel buttons provide the same path for keyboard and VoiceOver use. This is a local demonstration, not a modifier assignment. Its request payloads contain only practiceTool IDs and never reach ControlBridge.

Readiness copy distinguishes desktop requirements from the always available local exercises. It explains missing Accessibility, an unassigned radial modifier, capture in progress, Pointer On, and the need to close the practice window before desktop drawing/radial use. Readiness is read-only and refreshes once per second while the window is open.

## Reusable API and callbacks

- `GettingStartedPracticeSession(pointerConfiguration:)` owns lesson selection, local pointer/Interact switches, click and annotation counts, replay generation and a local DrawingPracticeSession. `select`, `replayStep`, `replayAll`, `cancel` and `stop` are testable without a window. It contains no overlay or preferences adapter.
- `PracticeLesson` supplies titles, instructions and a typed shortcut target. `PracticeReadiness.message(for:)` formats injected readiness without requesting permissions.
- `GettingStartedPracticeWindow.show(_:)` opens or focuses one normal native window at the requested lesson. `openShortcut`, `readiness` and `onVisibilityChanged` are its AppDelegate callbacks. Local preview views are destroyed on close.
- Pointer rendering uses existing PointerPreviewConfiguration/PointerPreviewView and its underlying playback. The host observes only native window focus notifications to cancel playback. Drawing uses existing DrawingPracticeConfiguration/Session/Canvas; no drawing renderer was added or changed.
- `WelcomeWindow.onPractice` is separate from existing `onTryIt`.
- `SettingsWindow.openPractice` forwards to `SettingsModel.openPractice`, taking a PracticeLesson. `MenuBarControls.openPractice` forwards to `MenuBarCommands.openPractice`. AppDelegate's private `openPractice(_:)` closes controls before showing the window and refreshes ordinary presentation context.
- `GettingStartedPracticeWindow.openShortcut` calls `SettingsWindow.showShortcut(_:)`. `SettingsModel.focusShortcut(_:)` publishes a fresh ShortcutFocusRequest for repeated links, switches to Shortcuts, and never calls shortcut application or recording callbacks. SettingsView's existing page ScrollView gets a ScrollViewReader; SettingsSection cases and switches are unchanged.
- The destination modifier identifies, outlines and focuses the relevant row. It never focuses or invokes ShortcutRecorder. Targets are `pointer -> toggle`, `interact -> mode`, `drawing -> pen`, and `radial -> radial` for the Hold to open row. Parent can merge per-row conflict logic independently; ShortcutField and recorder implementation are untouched.

## Glossary and copy proposals

| Term | Proposed meaning |
| --- | --- |
| Getting Started Practice | Replayable local window teaching Pointer On, Interact, drawing and quick controls. |
| Practice pointer | Independent preview of the current pointer. Its On/Off control changes only the sample. |
| Interact in Practice | Local switch deciding whether the practice canvas draws. It never changes desktop Interact. |
| Replay Step | Reset the current exercise and its disposable local values. |
| Start Again | Return to the first practice step. |
| Hold Menu | Keyboard-accessible equivalent of beginning the local radial hold. |

Primary copy: "Practice stays in this window. No permission or shortcut is needed." Shortcut helper: "Shortcuts stay unassigned until you choose them." Radial Settings help is shortened to hold, category, release, inward/back and Escape, plus a Try It link. Existing detailed edge and readiness restrictions remain summarized in one secondary paragraph.

## Local evidence

Passed 16 tests in GettingStartedPracticeTests, DrawingPracticeTests and PointerPreviewTests on this Mac. The final test build compiled the application and test targets with no warnings. Six new tests cover:

- Four lessons, replay and visibility/Interact independence.
- Cancellation of local drawing drafts and radial state on mode/lesson changes.
- Real radial category/candidate thresholds, local selection feedback, center cancellation and explicit cancellation.
- No persistent preference writes, no assignment changes, no recording/application callbacks and no live ink/history changes. The test seeds existing pointer/Interact shortcuts and a radial modifier, then verifies their preservation.
- Exact shortcut target mapping and fresh IDs for repeated navigation to the same row.
- Plain readiness explanations for unassigned modifiers, missing Accessibility, active capture and ready desktop use, while local exercises remain usable.

Command:

```sh
TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit.practice.s050 \
TH_HANDS_DIR=/tmp/lhp-practice-s050/Hands \
TH_THUMBNAILS_DIR=/tmp/lhp-practice-s050/Thumbnails \
swift test --scratch-path .build \
  --filter 'GettingStartedPracticeTests|DrawingPracticeTests|PointerPreviewTests'
```

Log: `/tmp/lhp-practice-s050-tests.log`. Grid lint passed GettingStartedPractice.swift, GettingStartedPracticeWindow.swift, PresentationSettings.swift and SettingsView.swift. `git diff --check` passed. No hosted CI, UI automation, native event posting, install, packaging, signing, notarization, PR, push or delivery ran. Normal preferences, actual Hands and root untracked assets were not modified. No central backlog, glossary, fix log, validation or milestone document was edited.

## Exact parent UI checks still required

1. In an isolated review instance, capture active-window Light and Dark appearances for all four lessons, General's new card, Shortcuts' shortened radial help, and Welcome's added button. Check at 560 x 520 minimum and 560 x 600 initial practice sizes, with Always Show Scroll Bars, Increase Contrast, Reduce Transparency and Reduce Motion. Verify text is readable and the radial labels, selection dot and button row do not clip. Certify the practice/Settings grid probes and check layout files; visual certification has not run here.
2. Launch once with a fresh isolated welcome domain and once with onboarding already marked shown. Existing users get no forced window. Show Pointer must still set Interact on and activate the current desktop pointer through the unchanged callback. The new practice button must open only local practice, including from the denied drawing card. Escape and Close should leave no local timer or ink active.
3. Use every entry point: Welcome, General Try It, More Commands, and the radial Shortcuts Try It. The last must start on step 4. Repeated entry focuses one window. Back/Next/Replay Step/Start Again must reset local progress and never modify actual pointer, mode, tool, sound, ink, Hands or shortcut assignments.
4. Turn the sample pointer on/off. Move/click inside its preview; test a hand, Laser, Spotlight and Presentation pointer. With Interact on, Try This Button increments its count. With Interact off it is disabled and local canvas drags add ink. Verify Undo/Clear/count feedback and Escape during a stroke. Changing steps or opening Shortcuts during a press must cancel the unfinished local gesture.
5. Hold the radial center, drag right to Tools, then up to Pen and release. Repeat for the other visible tools. Confirm candidate feedback, inward backtracking, center cancellation, Escape, focus loss and close. Repeat through the five native keyboard buttons. Desktop tool, modifiers, radial assignment, Interact and ink must remain unchanged. Confirm no Accessibility or Screen Recording prompt appears for local practice, including under denied permissions.
6. Activate each optional Shortcuts link, including twice to the same target and while Settings is already open at another section/scroll position. Verify the exact row is visible, outlined and keyboard-focused; no recorder is running and no keys are saved. Targets: Turn pointer on or off, Toggle Interact, Pen Tool and Hold to open. Native Tab navigation should still reach controls. Assignment must begin only after explicitly clicking the recorder or choosing a modifier.
7. Exercise readiness with Accessibility denied/allowed, radial Unassigned/assigned and capture busy/idle. Copy must update while open, describe desktop requirements, and leave every local lesson available. The desktop radial must remain suppressed while the app window owns input.
8. Keyboard-only and VoiceOver: logical reading/focus order, named native controls, usable Back/Next/Done, local radial button path and readable feedback/counts. Check Command-W closes practice, Escape cancels temporary local input, and native editing shortcuts in Settings keep their normal behavior.

Implementation is complete. Native UI, accessibility, actual focus/scroll behavior and integrated packaging acceptance remain with the parent as assigned.
