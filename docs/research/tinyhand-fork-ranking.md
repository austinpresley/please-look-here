# TinyHand fork audit and macOS ranking

I would build on current TinyHand and borrow selected changes. First make Point/Draw predictable, then add undo, clearer annotations, zoom, capture and a toolbar you can hide. TinyPointer is the richest presentation donor. AiHand has useful drawing and capture work, but its agent workspace should be a separate product decision.

## Coverage

Snapshot: 9 November 2026, 07:16 UTC. Enumerated 42 public forks and all 56 advertised fork branches, then checked their reachable Git histories and file diffs against upstream c5fb36b. The 43 fork-list endpoints were exhausted, including the original and every discovered fork. Renamed forks are included. Nine forks have Mac-relevant changes, seven have only Windows/Linux work, 19 are identical to upstream, and seven are behind with no new commits. Identical branch content and merged feature branches are counted once as ideas. This covers public branches visible at the snapshot, not private, deleted or unadvertised branches.

[Original repository](https://github.com/nilbuild/tinyhand) · [Fork network API](https://api.github.com/repos/nilbuild/tinyhand/forks?per_page=100&sort=oldest) · [Pinned upstream source](https://github.com/nilbuild/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47)

Current upstream already has custom hand import, a laser, pinned styles, configurable toggle/clear shortcuts, selectable ink colors, adjustable fade including permanent ink, sound choices, launch at login, automatic updates and native appearance. These are not new fork inventions. None of the inspected macOS feature branches is ahead because it simply copied a newer upstream main.

## Ranked changes

Scores are my judgment of usefulness for a better macOS pointing/presentation app, not measurements or code-quality grades. 9-10 = core additions; 7-8 = strong additions; 5-6 = situational; 1-4 = supporting work, personal choices or changes to skip. Rank within a score reflects priority. Effort is a rough integration estimate. I read source and diffs; I did not build or run the forks. Large features still need local runtime verification.

### 1. Use the Mac normally with the hand visible · 10/10 · C01

Make normal clicks, double-clicks, right-clicks and drags reach the app underneath. Switch explicitly into Draw when you want annotations.

**My take.** This fixes the biggest everyday limitation: turning the hand on currently takes over your clicks. It makes the app useful for live demos as well as pointing.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** Choose one shared Point/Draw model. The three forks are alternative implementations, so combining their input handlers would create unnecessary conflicts.

Sources: [charlesanim/InputTap.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/InputTap.swift); [sergvax/InputTap.swift](https://github.com/sergvax/tinyhand/blob/05ade042c6d77d534505dbd6c269909d90befd9f/Sources/TinyHand/InputTap.swift); [PlayPointer/OverlayController.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/OverlayController.swift)

### 2. Undo the last annotation · 9/10 · C02

Remove the most recent ink stroke with Command-Z instead of clearing everything.

**My take.** A drawing tool needs a cheap way to fix a mistake. This matters more than adding more pointer artwork.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** AiHand provides undo. A complete redo stack is not established by this audit.

Sources: [AiHand/Ink.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Ink.swift); [AiHand/OverlayController.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/OverlayController.swift)

### 3. Arrows, rectangles and text labels · 9/10 · C03

Add explicit freehand, rectangle, arrow and text tools, with a small drawing tool strip and thickness choices. TinyPointer also draws an arrowhead when a modifier is held.

**My take.** These tools communicate steps and UI feedback much more clearly than freehand scribbles alone.

**Recommendation.** Take. Estimated effort: large.

**Integration note.** AiHand's tool palette is tied to its annotation flow. Extract the drawing tools without requiring an agent session.

Sources: [AiHand/DrawingToolsPanel.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/DrawingToolsPanel.swift); [AiHand/Ink.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Ink.swift); [AiHand/InkTextEditor.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/InkTextEditor.swift); [TinyPointer/Ink.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Ink.swift)

### 4. Hold a key to magnify part of the screen · 9/10 · C04

A circular loupe follows the pointer, with adjustable diameter, 1.5x to 6x zoom and optional animation. It excludes the app's own windows from its capture.

**My take.** Small text and controls become readable during teaching, screen sharing and recorded demos.

**Recommendation.** Take. Estimated effort: large.

**Integration note.** Requires Screen Recording permission and a live capture stream. Keep it opt-in and check display changes, performance and full-screen behavior locally before shipping.

Sources: [TinyPointer/Magnifier.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Magnifier.swift); [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift)

### 5. Capture a screenshot with the hand and ink · 9/10 · C05

Take a screenshot that includes the pointer and drawing, omits the toolbar and hints, and can copy to the clipboard and save to a chosen folder.

**My take.** Turns a temporary explanation into something you can send immediately.

**Recommendation.** Take. Estimated effort: large.

**Integration note.** maxnetdigital's capture defaults to secondary click. Keep that gesture configurable because another fork uses right-click to exit and Point mode needs native right-click. Shots initiated from the toolbar temporarily hide the hand so it does not point at the hidden camera button.

Sources: [maxnetdigital/Capture.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/Capture.swift); [maxnetdigital/OverlayController.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/OverlayController.swift); [maxnetdigital/Preferences.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/Preferences.swift)

### 6. Hide or move the toolbar · 9/10 · C06

Add a persistent show/hide option and keyboard toggle. Let the toolbar move above the Dock, remember its position and reset it from its drag handle.

**My take.** A presentation overlay should not cover the content you are explaining or keep appearing at the bottom of the screen.

**Recommendation.** Take. Estimated effort: small to medium.

**Integration note.** alcibiadesc's small patch deliberately keeps the permission repair control reachable. TinyPointer adds the movable toolbar. Preserve both behaviors.

Sources: [alcibiadesc/OverlayController.swift](https://github.com/alcibiadesc/tinyhand/blob/c161c8b4bbda56990972e6f3032a3639ddae3028/Sources/TinyHand/OverlayController.swift); [TinyPointer/Toolbar.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Toolbar.swift); [TinyPointer/OverlayController.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/OverlayController.swift)

### 7. Numbered step markers · 8/10 · C07

Place numbered circles with a modifier-click, drag them to reposition and click an existing marker to remove it. Text color adapts to the marker background.

**My take.** Useful for explaining an ordered process without writing numbers by hand.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** TinyPointer bundles Playpen Sans under the OFL. Preserve its license if reusing the font.

Sources: [TinyPointer/Ink.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Ink.swift)

### 8. Control line width and opacity separately · 8/10 · C08

Choose stroke size independently of the hand size, plus ink opacity. AiHand supplies five thickness levels; TinyPointer exposes size and opacity sliders. The Rust/Tauri branch also separates pen thickness from pointer size.

**My take.** A large visible hand should not force a thick line, and translucent ink can mark text without obscuring it.

**Recommendation.** Take. Estimated effort: small to medium.

**Integration note.** Pick one set of controls rather than importing two competing thickness systems.

Sources: [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift); [TinyPointer/Ink.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Ink.swift); [AiHand/Preferences.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Preferences.swift); [tran-huy-phuc/engine.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/core/src/engine.rs)

### 9. Keep drawing silent while taps still make sound · 8/10 · C09

Play the sound only when a press ends as a tap. TinyPointer also offers an option to keep sound on drawing if desired.

**My take.** Removes the click sound at the start of every line. A small change with an obvious benefit.

**Recommendation.** Take. Estimated effort: small.

**Integration note.** Sound moves from mouse-down to mouse-up, so the tap sound arrives slightly later.

Sources: [alcibiadesc/OverlayController.swift](https://github.com/alcibiadesc/tinyhand/blob/d8ce59056b2bf65899c5c38d24aaebca0134a2f6/Sources/TinyHand/OverlayController.swift); [TinyPointer/OverlayController.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/OverlayController.swift); [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift)

### 10. Tap a key to switch back to normal mouse use · 8/10 · C10

A quick lone Shift tap latches mouse mode on or off. The key is configurable, with an orange menu icon and optional mode hint.

**My take.** Avoids holding Option for a long sequence of normal clicks, typing and dragging.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** Use it as a shortcut for the same Point/Draw state from C01. Avoid adding a separate third interaction mode. The implementation rejects modifier taps combined with typing or clicks.

Sources: [alcibiadesc/InputTap.swift](https://github.com/alcibiadesc/tinyhand/blob/a222e24d78bd4c39253f4fa96f654308192961db/Sources/TinyHand/InputTap.swift); [alcibiadesc/OverlayController.swift](https://github.com/alcibiadesc/tinyhand/blob/a222e24d78bd4c39253f4fa96f654308192961db/Sources/TinyHand/OverlayController.swift); [alcibiadesc/Preferences.swift](https://github.com/alcibiadesc/tinyhand/blob/a222e24d78bd4c39253f4fa96f654308192961db/Sources/TinyHand/Preferences.swift)

### 11. Export just the drawing as a transparent PNG · 8/10 · C11

Save all strokes since the last clear as a tightly cropped transparent image. Strokes remain exportable even after they fade from the screen.

**My take.** Lets you reuse arrows, diagrams or handwritten notes without the desktop behind them.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** Keep retained stroke data separate from visible layers and define when the retained drawing is cleared.

Sources: [charlesanim/Ink.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/Ink.swift); [charlesanim/Capture.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/Capture.swift); [charlesanim/OverlayController.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/OverlayController.swift)

### 12. Keep a separate drawing on each monitor · 8/10 · C40

Park each display's ink when the pointer moves to another display, then restore it when you return. The Rust Mac backend calls the shared engine's monitor switching implementation.

**My take.** Moving the hand between displays should not erase the explanation you just drew. This matters on a Mac with an external monitor.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** Only the active monitor's drawing is shown in this fork. Borrow the storage idea into the native app; decide separately whether inactive displays should keep showing their annotations.

Sources: [tran-huy-phuc/engine.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/core/src/engine.rs); [tran-huy-phuc/overlay.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/app/src/platform/macos/overlay.rs)

### 13. Record a short demo or selected screen region · 8/10 · C12

maxnetdigital records a display with the hand and ink. AiHand adds right-drag region selection, a recording toolbar, playback and a save/comment/send flow. The display recorder has toolbar and menu actions, a configurable capture shortcut and a double secondary-click gesture, with a click or Esc to stop.

**My take.** A short annotated recording often explains motion or a bug better than a still image.

**Recommendation.** Adapt. Estimated effort: large.

**Integration note.** maxnetdigital includes the hand and ink; AiHand's region recorder excludes the app overlays and shows the real cursor. They also use different frame-rate settings. Passing a video path to an agent does not establish video understanding. Both implementations are video-only, with no audio track in the reviewed code.

Sources: [maxnetdigital/Capture.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/Capture.swift); [AiHand/RegionRecorder.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/RegionRecorder.swift); [AiHand/VideoAnnotatePreview.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/VideoAnnotatePreview.swift)

### 14. Local commands for launchers and automation · 8/10 · C13

A versioned --ctl JSON interface reports state, turns the pointer on or off, chooses styles or laser, clears ink, changes pins and sound, opens settings, and validates settings batches.

**My take.** Makes reliable integrations possible for Raycast, scripts and other local tools. Explicit on/off is better than blindly toggling.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** The fork adds a private Unix socket with same-user checks and limits. It is the control foundation, not a completed Raycast extension. The app must already be running.

Sources: [0xdhrv/ControlBridge.swift](https://github.com/0xdhrv/tinyhand/blob/602e3f4ad3c0436bd06fa7a97b318246e3bdff2a/Sources/TinyHand/ControlBridge.swift); [0xdhrv/ControlTransport.swift](https://github.com/0xdhrv/tinyhand/blob/602e3f4ad3c0436bd06fa7a97b318246e3bdff2a/Sources/TinyHand/ControlTransport.swift)

### 15. Capture only the focused window · 8/10 · C14

Choose the whole screen or the focused window for annotated screenshots.

**My take.** Keeps feedback focused and reduces the amount of unrelated desktop content in a capture.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** AiHand crops the visible display to the frontmost ordinary window's bounds. It does not recover hidden parts of an occluded window. Check coordinates across multiple monitors and Retina scales.

Sources: [AiHand/WindowCapture.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/WindowCapture.swift); [AiHand/Preferences.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Preferences.swift)

### 16. More keyboard controls while presenting · 8/10 · C15

Add shortcuts for toolbar visibility, sound, automatic or rainbow ink, next/previous pointer and Settings. Single-key shortcuts are registered only while the pointer is on, with keyboard-layout-aware letter lookup for several defaults.

**My take.** Keeps common changes one key away without opening Settings or moving onto the toolbar.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** Use configurable shortcuts and suspend them during text entry. TinyPointer changes several defaults; those particular bindings are not a reason to adopt the feature.

Sources: [TinyPointer/AppDelegate.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/AppDelegate.swift); [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift)

### 17. A visible ring where you click · 8/10 · C16

Briefly highlight the click location. TinyPointer uses a tap circle; PlayPointer uses a small reusable pool of pulse rings and respects Reduce Motion.

**My take.** Viewers can see exactly where an action happened even if the hand partially covers the control.

**Recommendation.** Take. Estimated effort: small to medium.

**Integration note.** Keep it optional and carry over the Reduce Motion handling.

Sources: [TinyPointer/ArmView.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/ArmView.swift); [PlayPointer/ClickPulse.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/ClickPulse.swift)

### 18. Smoother drawn lines · 8/10 · C17

Resample and smooth strokes with four smoothing strengths while keeping the endpoint at the pointer. Arrow strokes use stronger smoothing.

**My take.** Trackpad annotations look cleaner without making the hand visibly lag behind.

**Recommendation.** Take. Estimated effort: medium.

**Integration note.** This is source-level behavior, not a measured latency result. Check responsiveness with a mouse and trackpad before choosing the default strength.

Sources: [TinyPointer/Ink.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Ink.swift); [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift)

### 19. Reach Settings even when the menu icon is hidden · 8/10 · C18

Opening the app again brings up Settings, and the overlay toolbar has a Settings button.

**My take.** MacBook notches and crowded menu bars can hide the app's only obvious way into Settings.

**Recommendation.** Take. Estimated effort: small.

**Integration note.** A small, independent change from maxnetdigital's larger capture feature.

Sources: [maxnetdigital/AppDelegate.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/AppDelegate.swift); [maxnetdigital/Toolbar.swift](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/Sources/TinyHand/Toolbar.swift)

### 20. Better recovery when drawing permission fails · 7/10 · C19

PlayPointer can run its control mode without first starting the drawing interception tap, gates Draw on permission, falls back to Control, and explains how to repair drawing access.

**My take.** A broken permission state should still leave the app understandable and usable for pointing.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** This changes onboarding and input setup together. Test permission denied, revoked and re-granted states locally.

Sources: [PlayPointer/OverlayController.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/OverlayController.swift); [PlayPointer/WelcomeWindow.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/WelcomeWindow.swift)

### 21. Keep mouse presses routed consistently · 7/10 · C20

charlesanim and PlayPointer track the route of each mouse button from press through release. PlayPointer also guards callbacks with a generation value when activity changes. PlayPointer also checks hardware button state to recover a missed left-button release.

**My take.** This is useful groundwork for mode changes without mismatched mouse-down and mouse-up handling.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** It supports C01 rather than adding a visible feature. The source changes do not prove every stuck-button case is fixed.

Sources: [charlesanim/InputTap.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/InputTap.swift); [PlayPointer/InputTap.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/InputTap.swift)

### 22. Pick pointers from a toolbar catalog with recents · 7/10 · C21

PlayPointer exposes the full pointer catalog above a horizontally scrollable toolbar and moves recently used styles to the front. It loads thumbnails for visible items.

**My take.** Useful once the pointer collection grows beyond the existing eight pinned slots.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** Keep a compact favorites path so a large catalog does not make routine switching slower.

Sources: [PlayPointer/Toolbar.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/Toolbar.swift); [PlayPointer/Preferences.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/Preferences.swift)

### 23. A plain dot that matches the ink · 7/10 · C22

TinyPointer adds a color pointer whose dot uses the line's size, color and opacity. Ink swatches are directly visible in its toolbar. It also corrects automatic ink for the white glove to white.

**My take.** A simple pointer can suit a formal presentation better than a novelty hand, while keeping annotation color consistent.

**Recommendation.** Take. Estimated effort: small to medium.

**Integration note.** The original already has a laser. The new value is an ink-matched dot and faster color access.

Sources: [TinyPointer/PointerStyle.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/PointerStyle.swift); [TinyPointer/ArmView.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/ArmView.swift); [TinyPointer/Toolbar.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Toolbar.swift)

### 24. Preview, copy and drag captured images · 7/10 · C23

AiHand adds a screenshot preview with save/drag behavior, a Command-Shift-C copy action, and full-size open/copy actions for images in chats. It also posts native screenshot saved/copied notifications, with an image attachment for saved shots.

**My take.** Reduces the steps between making an annotation and using it in another app.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** The capture preview is useful independently. Chat-specific image actions only matter if chat becomes part of this app.

Sources: [AiHand/ScreenshotSavePreview.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/ScreenshotSavePreview.swift); [AiHand/ChatImageActions.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/ChatImageActions.swift); [AiHand/OverlayController.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/OverlayController.swift); [AiHand/ScreenshotNotifier.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/ScreenshotNotifier.swift)

### 25. Local Mac builds without requiring full Xcode · 7/10 · C24

TinyPointer adds an external build directory, SDK selection, local signing/install support and a DMG fallback. sergvax adds a TINYHAND_SDK override, date-based build numbers and ad-hoc signing. AiHand expands local release and debug scripts.

**My take.** Useful for developing this fork on your Mac and keeping packaging local.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** Reuse the local workflow ideas with your own app identity and updater configuration. The forks' hosted workflow changes are outside your requested setup.

Sources: [TinyPointer/build-local.sh](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/scripts/build-local.sh); [TinyPointer/lib.sh](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/scripts/lib.sh); [sergvax/build-app.sh](https://github.com/sergvax/tinyhand/blob/05ade042c6d77d534505dbd6c269909d90befd9f/scripts/build-app.sh); [AiHand/release.sh](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/scripts/release.sh)

### 26. Draw on the screen and send it to a coding agent · 7/10 · C25

AiHand captures the annotation, opens a shared prompt composer, and sends it through Cursor Agent, Claude Code or Codex CLI. Enter opens a comment; Command-Enter can send.

**My take.** A strong direction for visual bug reports and UI work if you want this to become a developer tool.

**Recommendation.** Later. Estimated effort: large.

**Integration note.** This adds a second product to maintain. Its Claude adapter uses --dangerously-skip-permissions and Cursor uses --force/--trust. Reconsider those defaults before reusing the integration.

Sources: [AiHand/OverlayController.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/OverlayController.swift); [AiHand/AnnotatePromptPanel.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/AnnotatePromptPanel.swift); [AiHand/AgentCLI.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/AgentCLI.swift)

### 27. Saved agent sessions and project folders · 7/10 · C26

Persist conversations across restarts, archive sessions, queue or steer follow-ups, resize and remember the chat panel, and restore the selected chat per workspace. A workspace picker exposes paths, session indicators and Option-1 through Option-9 shortcuts. Completion notifications can bring you back to the relevant session, and the menu bar shows workspace session counts.

**My take.** Useful if draw-to-agent becomes a core workflow rather than a one-shot handoff.

**Recommendation.** Later. Estimated effort: large.

**Integration note.** The sessions panel alone is over 2,000 source lines. Borrow the behavior selectively instead of taking the whole subsystem by default.

Sources: [AiHand/SessionStore.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SessionStore.swift); [AiHand/SessionsSidePanel.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SessionsSidePanel.swift); [AiHand/AgentSessionRunner.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/AgentSessionRunner.swift); [AiHand/SessionNotifier.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SessionNotifier.swift)

### 28. Try display-linked pointer updates · 7/10 · C27

AiHand changes tracking to use a display link and mouse events, with different grip-follow behavior.

**My take.** Worth investigating if pointer latency becomes noticeable during real use.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** No comparative performance measurements were run. Preserve upstream's idle throttling benefits and measure before choosing this implementation.

Sources: [AiHand/OverlayController.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/OverlayController.swift); [AiHand/ArmView.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/ArmView.swift)

### 29. Freeform screenshot cutouts · 6/10 · C28

Trace a closed freehand shape, then save only the screen pixels inside it. The outside is transparent and the pointer, toolbar and ink are omitted.

**My take.** Handy for irregular cutouts, though ordinary screen or window capture will cover more daily needs.

**Recommendation.** Later. Estimated effort: medium to large.

**Integration note.** charlesanim's upstream PR was closed without merging, but the code is present in that fork's main branch. Cancellation preserves the selection.

Sources: [charlesanim/Capture.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/Capture.swift); [charlesanim/OverlayController.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Sources/TinyHand/OverlayController.swift)

### 30. Animated cats, rockets and other playful pointers · 6/10 · C29

PlayPointer adds a larger catalog, including cats, a rocket, squeaky toy, Nyan Cat and bongo cat. Several have pressed poses, following or pouncing behavior, trails, and style-specific sounds.

**My take.** Can give the app personality, especially for teaching, but does less for its core usefulness than better interaction and annotation.

**Recommendation.** Later. Estimated effort: medium to large.

**Integration note.** Choose a small original collection and review third-party character/art rights before reuse. Respect Reduce Motion as the animation code does in several paths.

Sources: [PlayPointer/PointerStyle.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/PointerStyle.swift); [PlayPointer/ArmView.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/ArmView.swift); [PlayPointer/TapSound.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/TapSound.swift)

### 31. Rainbow ink · 6/10 · C30

Cycle color along a line with adjustable speed and hue shift between strokes. TinyPointer can continue from the previous line's ending color and resets its sequence when cleared.

**My take.** A recognizable presentation effect, but a lower priority than clear shapes, undo and line control.

**Recommendation.** Later. Estimated effort: medium.

**Integration note.** Adds segmented drawing and smoothing work. A simple solid-color path should remain cheap.

Sources: [TinyPointer/Ink.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Ink.swift); [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift)

### 32. Theme override and smaller pointer sizes · 6/10 · C31

AiHand adds System/Light/Dark appearance choices and lowers the minimum pointer size from 0.08 to 0.04.

**My take.** Useful preferences for a larger annotation workspace, with modest benefit for the tiny original app.

**Recommendation.** Adapt. Estimated effort: small.

**Integration note.** The original already supports native appearance. A theme override is an extra choice, not the introduction of dark mode.

Sources: [AiHand/Preferences.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Preferences.swift); [AiHand/SettingsView.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SettingsView.swift)

### 33. Model favorites and skill autocomplete · 6/10 · C32

AiHand stores favorites per agent CLI, exposes model and effort choices, supports Command-/ model cycling, and autocompletes installed skills in the composer.

**My take.** Helpful inside an established agent workflow. Little value for a presentation-only app.

**Recommendation.** Later. Estimated effort: large.

**Integration note.** Depends on CLI formats and catalogs that can change. Keep the adapters separate if adopting this direction.

Sources: [AiHand/AgentModelCatalog.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/AgentModelCatalog.swift); [AiHand/SkillCatalog.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SkillCatalog.swift); [AiHand/SkillAutocomplete.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SkillAutocomplete.swift)

### 34. Reorganize settings and polish the toolbar · 6/10 · C33

TinyPointer separates Shortcuts, Draw and Zoom pages, adds native right-aligned menu shortcut labels, larger toolbar spacing, custom hover/help states and macOS 26 glass with fallbacks. Ink renders below the toolbar. PlayPointer adds mode-specific drawing hints. The Tauri branch adds a toolbar tools row, clear action and optional hover hints.

**My take.** Useful when adding more controls, especially making mode and keyboard help easier to find.

**Recommendation.** Adapt. Estimated effort: medium.

**Integration note.** Design the final settings around the features you actually keep. Do not import every new page or purely visual choice automatically.

Sources: [TinyPointer/SettingsView.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/SettingsView.swift); [TinyPointer/Toolbar.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Toolbar.swift); [TinyPointer/AppKitHelpers.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/AppKitHelpers.swift); [PlayPointer/Toolbar.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/Toolbar.swift); [tran-huy-phuc/toolbar.html](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/ui/toolbar.html)

### 35. Right-click to end the pointer session · 5/10 · C34

TinyPointer optionally makes a secondary click exit; right-click on the toolbar drag handle instead resets its position.

**My take.** Convenient for a presentation-only mode, but a specialized gesture.

**Recommendation.** Adapt. Estimated effort: small.

**Integration note.** Conflicts with right-click capture and ordinary context menus. Pick one explicit secondary-click policy per mode.

Sources: [TinyPointer/InputTap.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/InputTap.swift); [TinyPointer/OverlayController.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/OverlayController.swift)

### 36. A real language choice for English and Vietnamese · 5/10 · C41

The Rust/Tauri branch has a saved English/Vietnamese language choice, with localized menus and UI strings. The same UI is used by its Mac implementation.

**My take.** This is a more reusable localization approach than replacing all English text with one other language. Its priority depends on your intended audience.

**Recommendation.** Later. Estimated effort: medium.

**Integration note.** The dictionaries live in a web UI and Rust menu layer. A Swift app should use native localization rather than inherit that architecture just to gain translations.

Sources: [tran-huy-phuc/i18n.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/app/src/i18n.rs); [tran-huy-phuc/i18n.js](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/ui/i18n.js); [tran-huy-phuc/settings.html](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/ui/settings.html)

### 37. More documentation, demos and verification helpers · 4/10 · C35

Forks add feature documentation, screenshots, changelogs, demo clips, input/capture tests and evidence helpers. 0xdhrv documents its control protocol and adds handler/socket regression checks. AiHand fixes SettingsWindow lifetime for its screenshot verification mode.

**My take.** Useful supporting work for whichever features are selected. It is not an additional app capability.

**Recommendation.** Adapt. Estimated effort: small to medium.

**Integration note.** This audit inspected source without running fork builds or their tests. Documentation and claimed validation are not proof of runtime readiness.

Sources: [TinyPointer/README.md](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/README.md); [maxnetdigital/README.md](https://github.com/maxnetdigital/tinyhand/blob/01b845c321ea77a4622f6b78dab86514adc21435/README.md); [charlesanim/InputTapTests.swift](https://github.com/charlesanim/tinyhand/blob/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995/Tests/TinyHandTests/InputTapTests.swift); [0xdhrv/control-protocol.md](https://github.com/0xdhrv/tinyhand/blob/602e3f4ad3c0436bd06fa7a97b318246e3bdff2a/docs/control-protocol.md); [AiHand/SettingsWindow.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/SettingsWindow.swift)

### 38. Replace the interface copy with Russian · 3/10 · C36

PlayPointer replaces many English interface strings and instructions with Russian.

**My take.** Valuable for that fork's audience, but there is no reason to replace the English UI in your app.

**Recommendation.** Skip. Estimated effort: medium.

**Integration note.** This is hardcoded copy replacement rather than a full language picker. If localization matters later, use a proper localized string system.

Sources: [PlayPointer/SettingsView.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/SettingsView.swift); [PlayPointer/WelcomeWindow.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/WelcomeWindow.swift)

### 39. Change defaults and make ink persistent · 3/10 · C37

Forks change initial shortcuts, selected styles, colors and sounds. AiHand keeps drawings until clear and removes the fade setting from its annotation workflow.

**My take.** These choices fit their authors' workflows. They are not new capabilities in themselves; upstream already supports keeping ink indefinitely.

**Recommendation.** Adapt. Estimated effort: small.

**Integration note.** Choose defaults after the combined interaction model is designed. Keep fading as an option unless your product direction clearly benefits from removing it.

Sources: [TinyPointer/Preferences.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Preferences.swift); [AiHand/Ink.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Ink.swift); [AiHand/Preferences.swift](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/Sources/AiHand/Preferences.swift); [PlayPointer/Preferences.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/Preferences.swift)

### 40. Remove automatic updates · 2/10 · C38

PlayPointer removes Sparkle and makes update checks open its releases page. TinyPointer briefly removes Sparkle in its first commit, then restores it with its own update feed and key.

**My take.** Losing automatic updates would be a step backward for a distributed Mac app.

**Recommendation.** Skip. Estimated effort: small.

**Integration note.** Your fork will need its own bundle identity, feed and signing configuration. Adapt that configuration without discarding the existing update capability.

Sources: [PlayPointer/Updater.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Sources/TinyHand/Updater.swift); [PlayPointer/Package.swift](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/Package.swift); [TinyPointer/Updater.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/Updater.swift); [TinyPointer/lib.sh](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/scripts/lib.sh)

### 41. Rewrite the Mac app in Rust and Tauri · 2/10 · C42

The windows-tauri branch also adds a real Mac backend with CGEventTap, AppKit windows, IOSurface double buffering, private cursor hooks, and a worker-thread renderer shared with the port. It renders changed rectangles and uses refresh-rate pacing with a slower idle loop.

**My take.** For a Mac-only app, this adds substantial migration work without a clear advantage over improving the existing Swift version. Take the useful behaviors independently.

**Recommendation.** Skip. Estimated effort: large.

**Integration note.** Its own notes list missing custom hands, editable shortcuts, onboarding hints and automatic updates, plus an Esc/menu behavior gap. A README sentence still calls the overlay a stub even though the source contains a Mac implementation. Performance claims were not independently measured.

Sources: [tran-huy-phuc/mod.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/app/src/platform/macos/mod.rs); [tran-huy-phuc/overlay.rs](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/app/src/platform/macos/overlay.rs); [tran-huy-phuc/README.md](https://github.com/tran-huy-phuc/tinyhand/blob/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd/desktop/README.md)

### 42. Rebrands, release versions and promotional edits · 1/10 · C39

Forks rename the app, targets, bundle IDs, support links, websites and release destinations, bump versions, revise banners and add their own author credits. TinyPointer migrates existing TinyHand settings into its new identity and updates skeleton artwork.

**My take.** Branding and release ownership must match your own app. The donors' names, endpoints and banner revisions are not improvements to carry over.

**Recommendation.** Skip. Estimated effort: small.

**Integration note.** Settings migration is useful when changing identity, and artwork fixes can be checked separately. Preserve original MIT attribution when reusing code.

Sources: [TinyPointer/main.swift](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/Sources/TinyPointer/main.swift); [TinyPointer/LICENSE](https://github.com/esreverse/tinypointer/blob/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e/LICENSE); [PlayPointer/lib.sh](https://github.com/omiusgm/playpointer/blob/d35254829b0a7411182272b2a81760c47261bbe5/scripts/lib.sh); [AiHand/lib.sh](https://github.com/rjiang-bb/aihand/blob/7b58e976d81031456ecf2e54cfc2269fa77d172e/scripts/lib.sh)

## Every fork inspected

| Fork | Branches inspected | Result |
|---|---|---|
| [0xdhrv/tinyhand](https://github.com/0xdhrv/tinyhand) | [f/native-control-bridge](https://github.com/0xdhrv/tinyhand/tree/602e3f4ad3c0436bd06fa7a97b318246e3bdff2a)<br>[main](https://github.com/0xdhrv/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | macOS changes. Local JSON controls, native state reporting and validated settings batches. |
| [AbdulRehman56/tinyhand](https://github.com/AbdulRehman56/tinyhand) | [linux-port](https://github.com/AbdulRehman56/tinyhand/tree/01457dc496e68b45bb6709049cc61945b3a7e4f5)<br>[linux-port-upstream](https://github.com/AbdulRehman56/tinyhand/tree/051445dd373a80b15a1b05e0d654d98e4aeba550)<br>[main](https://github.com/AbdulRehman56/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Platform only; excluded. Linux GNOME/Wayland and X11 work. |
| [alcibiadesc/tinyhand](https://github.com/alcibiadesc/tinyhand) | [hide-toolbar-option](https://github.com/alcibiadesc/tinyhand/tree/c161c8b4bbda56990972e6f3032a3639ddae3028)<br>[main](https://github.com/alcibiadesc/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47)<br>[quiet-strokes](https://github.com/alcibiadesc/tinyhand/tree/d8ce59056b2bf65899c5c38d24aaebca0134a2f6)<br>[shift-tap-mouse-mode](https://github.com/alcibiadesc/tinyhand/tree/a222e24d78bd4c39253f4fa96f654308192961db) | macOS changes. Three independent changes: hide the toolbar, silent drawing strokes, and a latched mouse mode. |
| [austinpresley/please-look-here](https://github.com/austinpresley/please-look-here) | [main](https://github.com/austinpresley/please-look-here/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [charlesanim/tinyhand](https://github.com/charlesanim/tinyhand) | [feat/drawing-capture-pointer](https://github.com/charlesanim/tinyhand/tree/0b622244e05beccb15bf54dd9c478d885ccb9d89)<br>[main](https://github.com/charlesanim/tinyhand/tree/8c9a83b1143a823282ea4f5c9bab6c22e4f3c995) | macOS changes. Native click-through, explicit drawing and screenshot modes, drawing PNG export and freeform screenshot cutouts. |
| [ChatGPTBuddy/tinyhand](https://github.com/ChatGPTBuddy/tinyhand) | [main](https://github.com/ChatGPTBuddy/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [devpeerapong/tinyhand](https://github.com/devpeerapong/tinyhand) | [main](https://github.com/devpeerapong/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [esreverse/tinypointer](https://github.com/esreverse/tinypointer) | [main](https://github.com/esreverse/tinypointer/tree/bdf5bacf9b8dda9c7aac7687c21fc8fff0f63c2e) | macOS changes. Zoom loupe, arrows, number stamps, line controls and smoothing, keyboard controls, movable toolbar, tap circles, rainbow ink and local build work. |
| [goose20090/tinyhand](https://github.com/goose20090/tinyhand) | [main](https://github.com/goose20090/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [gundusrikanth/tinyhand](https://github.com/gundusrikanth/tinyhand) | [main](https://github.com/gundusrikanth/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [haxllo/tinyhand](https://github.com/haxllo/tinyhand) | [main](https://github.com/haxllo/tinyhand/tree/f243657fcbbd0613e004908d188042c14dbb53a5) | Behind upstream; no new commits. 2 commits behind; no fork-authored changes. |
| [hetrodoo/tinyhand](https://github.com/hetrodoo/tinyhand) | [main](https://github.com/hetrodoo/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47)<br>[windows-port](https://github.com/hetrodoo/tinyhand/tree/b472c2449f0db3c11cdfc637eadcd3ad088513ff) | Platform only; excluded. Windows port. |
| [hotsync/tinyhand](https://github.com/hotsync/tinyhand) | [main](https://github.com/hotsync/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [iamdooboy/tinyhand](https://github.com/iamdooboy/tinyhand) | [main](https://github.com/iamdooboy/tinyhand/tree/f243657fcbbd0613e004908d188042c14dbb53a5) | Behind upstream; no new commits. 2 commits behind; no fork-authored changes. |
| [ITGalaxyMaster/tinyhand](https://github.com/ITGalaxyMaster/tinyhand) | [main](https://github.com/ITGalaxyMaster/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [its-harsshhh/tinyhand](https://github.com/its-harsshhh/tinyhand) | [main](https://github.com/its-harsshhh/tinyhand/tree/c45c014a1655ade74fa851ab9a6d36e155102066) | Behind upstream; no new commits. 4 commits behind; no fork-authored changes. |
| [jawond/tinyhand](https://github.com/jawond/tinyhand) | [main](https://github.com/jawond/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [luqmanoop/tinyhand](https://github.com/luqmanoop/tinyhand) | [main](https://github.com/luqmanoop/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [m1ga/tinyhand](https://github.com/m1ga/tinyhand) | [linux-kde-port](https://github.com/m1ga/tinyhand/tree/2d203e48be2621493d1ff2ff1d02dd132e252d1c)<br>[main](https://github.com/m1ga/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Platform only; excluded. Linux KDE/Qt port. |
| [mathewharwich/tinyhand](https://github.com/mathewharwich/tinyhand) | [main](https://github.com/mathewharwich/tinyhand/tree/f243657fcbbd0613e004908d188042c14dbb53a5) | Behind upstream; no new commits. 2 commits behind; no fork-authored changes. |
| [maxnetdigital/tinyhand](https://github.com/maxnetdigital/tinyhand) | [main](https://github.com/maxnetdigital/tinyhand/tree/01b845c321ea77a4622f6b78dab86514adc21435)<br>[snapshot-and-record](https://github.com/maxnetdigital/tinyhand/tree/7a1ec170d1f587ce60d819516164692bf24e495a) | macOS changes. Annotated screenshots, screen recording, clipboard/folder output and Settings access when the menu icon is hidden. |
| [mayurnimavatg/tinyhand](https://github.com/mayurnimavatg/tinyhand) | [main](https://github.com/mayurnimavatg/tinyhand/tree/c45c014a1655ade74fa851ab9a6d36e155102066) | Behind upstream; no new commits. 4 commits behind; no fork-authored changes. |
| [MUL7ii/tinyhand](https://github.com/MUL7ii/tinyhand) | [main](https://github.com/MUL7ii/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47)<br>[windows-port](https://github.com/MUL7ii/tinyhand/tree/ea40fa0b2ecf7c71d5336093623381ce2e6cc4db) | Platform only; excluded. Windows Rust port. |
| [nkemjp2/tinyhand](https://github.com/nkemjp2/tinyhand) | [main](https://github.com/nkemjp2/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [omiusgm/playpointer](https://github.com/omiusgm/playpointer) | [main](https://github.com/omiusgm/playpointer/tree/d35254829b0a7411182272b2a81760c47261bbe5) | macOS changes. Control/Draw modes, stronger mouse routing, pointer catalog and recents, animated characters, click pulses, drawing-permission recovery and Russian interface copy. |
| [p4block/tinyhand](https://github.com/p4block/tinyhand) | [main](https://github.com/p4block/tinyhand/tree/1e1977200d80b2925594c0ed9855f1a2f12a0bfe) | Platform only; excluded. Linux Wayland port, Arch packaging and Linux sound controls. |
| [Pikuseru/tinyhand](https://github.com/Pikuseru/tinyhand) | [main](https://github.com/Pikuseru/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [pparker13122/tinyhand](https://github.com/pparker13122/tinyhand) | [main](https://github.com/pparker13122/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [rjiang-bb/aihand](https://github.com/rjiang-bb/aihand) | [main](https://github.com/rjiang-bb/aihand/tree/7b58e976d81031456ecf2e54cfc2269fa77d172e) | macOS changes. Drawing tools and undo, screenshot scope and preview, region video, coding-agent handoff, saved sessions/workspaces, model favorites and skill completion. |
| [sajeeldigitali/tinyhand](https://github.com/sajeeldigitali/tinyhand) | [main](https://github.com/sajeeldigitali/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47)<br>[windows](https://github.com/sajeeldigitali/tinyhand/tree/2d7a33b9f2f4cd27abc9e9bdf7aad70a032186f9) | Platform only; excluded. Windows port. |
| [screenfluent/tinyhand](https://github.com/screenfluent/tinyhand) | [main](https://github.com/screenfluent/tinyhand/tree/c45c014a1655ade74fa851ab9a6d36e155102066) | Behind upstream; no new commits. 4 commits behind; no fork-authored changes. |
| [secondpathstudio/tinyhand_macos](https://github.com/secondpathstudio/tinyhand_macos) | [main](https://github.com/secondpathstudio/tinyhand_macos/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [sergvax/tinyhand](https://github.com/sergvax/tinyhand) | [main](https://github.com/sergvax/tinyhand/tree/05ade042c6d77d534505dbd6c269909d90befd9f) | macOS changes. Click-through by default, a persisted screen-drawing toggle, and Command Line Tools/local-signing build support. |
| [Shoaib19/tinyhand](https://github.com/Shoaib19/tinyhand) | [main](https://github.com/Shoaib19/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [sud868/tinyhand](https://github.com/sud868/tinyhand) | [feat/gnome-extension](https://github.com/sud868/tinyhand/tree/3d2fe91b2258354bf591f4d85e2c07e830dd1599)<br>[main](https://github.com/sud868/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Platform only; excluded. GNOME extension. |
| [tran-huy-phuc/tinyhand](https://github.com/tran-huy-phuc/tinyhand) | [main](https://github.com/tran-huy-phuc/tinyhand/tree/830cf6c1e3edfc96dbf35a7c39f08f4b28da0b33)<br>[windows-tauri](https://github.com/tran-huy-phuc/tinyhand/tree/0f2614e83118bf2754ce2cb1de23cb21beb9b4cd) | macOS changes. The windows-tauri branch also has a Rust/Tauri Mac implementation, per-monitor drawing retention, separate pen thickness and an English/Vietnamese language choice. Its main branch is the Windows-focused version. |
| [tumaranja/tinyhand](https://github.com/tumaranja/tinyhand) | [main](https://github.com/tumaranja/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [Ubaton/tinyhand](https://github.com/Ubaton/tinyhand) | [main](https://github.com/Ubaton/tinyhand/tree/c45c014a1655ade74fa851ab9a6d36e155102066) | Behind upstream; no new commits. 4 commits behind; no fork-authored changes. |
| [umairbari/tinyhand](https://github.com/umairbari/tinyhand) | [main](https://github.com/umairbari/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [vasinl124/tinyhand](https://github.com/vasinl124/tinyhand) | [main](https://github.com/vasinl124/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [wajahat-alip/tinyhand](https://github.com/wajahat-alip/tinyhand) | [main](https://github.com/wajahat-alip/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |
| [wanderberi/tinyhand](https://github.com/wanderberi/tinyhand) | [main](https://github.com/wanderberi/tinyhand/tree/c5fb36b7c4d7c87480958872a724b30a52427a47) | Identical to upstream. No fork-authored changes. |

## What I would combine first

1. Use one Point/Draw state. Borrow native clicking from charlesanim or sergvax, with the optional tap-to-switch shortcut from alcibiadesc. Use consistent per-button input routing.
2. Bring in the small presentation fixes: toolbar visibility, Settings access, quiet strokes and optional click rings.
3. Add undo, independent line width/opacity, arrows, rectangles, text, numbered markers and per-monitor ink retention.
4. Add the opt-in zoom loupe, then annotated screen/window capture and drawing export. Region video can follow.
5. Add local automation controls. Decide separately whether direct coding-agent sessions belong in this app.

These are proposed combinations of fork ideas. No feature implementation was changed as part of this audit.

## Collisions to resolve before copying code

- Normal right-click, capture and exit all compete for the same mouse button in different forks. Choose behavior by mode and make special gestures configurable.
- Point/Draw and the latched mouse shortcut should share one state. Do not add overlapping modes from several forks.
- AiHand permanently retains annotations for agent handoff; current upstream already offers fading or permanent ink. Retain the choice unless the new workflow requires otherwise.
- The forks modify the same input, overlay, toolbar and preferences files. Extract features in small steps instead of merging whole forks.
- Keep the app's own update feed, bundle identity and signing configuration. Donor release endpoints and hosted workflow edits do not belong in the local development workflow.

## Your ideas

No original feature ideas have been mixed into the ranking. This list is the researched starting point for your additions.

## Source evidence

The companion [detailed fork evidence](tinyhand-fork-evidence.md) records the per-fork audit and branch hashes. The local research cache at `/tmp/tinyhand-fork-audit-20261109` contains the API snapshots, histories and diffs used in the audit.
