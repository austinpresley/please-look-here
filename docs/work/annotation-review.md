# Annotation review implementation

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-5e3d578b`
Branch: `t3/display-ink-tools`
Scope: S-036, S-037 and S-052, review recommendations 1, 2 and 17.

## S-036 Preserve drawings across displays

- Added DisplayInkStore, keyed by stable CG display ID rather than origin, size or scale. Each display retains its Ink instance, exact local geometry and independent Undo/Redo. Disconnecting or resizing a display does not prune its document.
- The existing ArmView hosts the selected display's ink. Display changes end a drawing gesture and cancel the temporary text editor before switching documents. No extra window or permission is introduced.
- Pointer Off hides the annotation container and cancels drafts instead of resetting history. Explicit activation reveals it. Existing system shutdown still calls deactivate; recoverPresentation still returns immediately when inactive, so wake cannot reactivate.
- Local verification: isolated `swift test --filter 'DisplayInkTests|DrawingGeometryTests|InkInteractionTests'` passed 12 tests. Build/test log: `/tmp/lhp-annotation-s36-tests.log`.
- Display tests inject IDs and geometry, covering negative origins, unequal display sizes/scales, independent Undo/Redo, explicit off/on and same-ID geometry changes.
- Parent still owns actual multiple-display/mixed-scale, sleep/lock, UI and packaging checks. Simulated display tests do not establish hardware acceptance.

## Proposed glossary/copy

- Display document: annotations and Undo/Redo associated with one stable display identity for the running app session.
- No new user-facing copy in S-036.

## S-037 Make annotation fading consistent

- Added InkVisibility and an injected InkLifetimePolicy beside the existing injected clock. Policies are captured per gesture. Changing settings affects future or restored objects and does not resurrect expired ones.
- Whole-line visibility now uses the same clock as rendering, hit-testing and visible-state counts. Text, markers, rectangles and arrows fade as whole objects in both Whole Line and Trail. Freehand trail rendering still retains complete document geometry.
- Expired markers cannot be clicked or dragged. Pointer Off reports zero visible ink while keeping history. Undo/Redo remains available for expired semantic edits.
- Defined restoration: only objects newly restored or changed by Undo/Redo receive a fresh full lifetime under the current policy. Unaffected objects retain their visibility, including expiration. Undo Clear restores every full object. Redo of a creation also restarts that object's lifetime.
- Layer order follows document order after restores. Active-trail cancellation stops its clock; a held stroke can resume visibly after the eraser catches up.
- Regression evidence: the new first three visibility tests failed on the prior implementation with 12 assertions, including text opacity, expired counts, marker hit-testing and restoration. `/tmp/lhp-annotation-s37-red.log` records the failure.
- Local verification: isolated focused Swift tests passed 21 tests in five suites. `/tmp/lhp-annotation-s37-tests.log` records the result. No UI automation, installs, signing or packaging ran.
- Parent still owns integrated fading/controls appearance and actual display/hardware checks.

Proposed glossary additions:
- Annotation lifetime: visibility timing separate from an annotation's full geometry and Undo/Redo history.
- Restored visibility: full visibility with a fresh lifetime for an object added or changed by Undo/Redo; unaffected objects keep their prior lifetime.

## S-052 Edit individual annotations

UX and implementation:
- Choose Eraser with Interact off, press one visible object, then release to remove that one topmost object. Dragging does not sweep through other objects. Escape or cancellation leaves the document and history unchanged. One Undo restores the full object and its fresh lifetime.
- AnnotationHitTest owns selection geometry. It tests stroke outlines, arrow heads, rectangle borders, actual text bounds and marker circles. Partial trails are hit-tested only on their remaining path. Expired objects never become eraser targets.
- Highlighter reuses freehand pen geometry, smoothing, color and lifetime controls. It captures a width three times the stroke-width setting and opacity at 35% of the opacity setting. No separate color or shortcut preference is introduced.
- Appended Eraser and Highlighter after the existing five tools, preserving existing raw values and their relative order. The cycle is Pen, Rectangle, Arrow, Text, Number, Eraser, Highlighter, then Pen. New PresentationAction entries have no assigned shortcut.
- Existing enum-driven toolbar, Settings picker, native menus and radial tool choices include both tools. The radial Tools group now has two pages, with Highlighter on the second. The native menu bar segmented control uses 32-point segments, or 28 at the existing 280-point test width, to fit seven tools.
- JSON tool/cycle-tool use the unchanged validated ControlBridge selection path. AppleScript adds distinct LkEr and LkHi enumerators while preserving all previous codes. The Stream Deck Choose Tool enum and inspector gain both fixed choices without changing manifest UUIDs, saved settings or queue behavior.
- The Stream Deck replay script now covers seven choices and derives wrap expectations from the complete tool list. It was syntax-checked, not run against a live app or host.
- Follow-up integration details: annotation input reconciles its current display before mapping local coordinates. Same-display scale changes update retained layer/text contentsScale without changing geometry. Toolbar Clear and an open radial History group track visible ink while Undo/Redo retain semantic availability. Escape cancellation leaves the existing InputTap press owner to drain its release; native text editors keep their existing behavior.

Verification:
- Final isolated command: `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.annotation-review TH_HANDS_DIR=/tmp/lhp-annotation-review-hands swift test --filter 'AnnotationEditingTests|InkVisibilityTests|DisplayInkTests|DrawingGeometryTests|InkInteractionTests|TrailTests|ControlTests|AppleScriptTests|DeckKeyTests|RadialTests|ToolbarTests|MenuBarTests'`.
- Result: 88 tests in 12 suites passed, including a six-tool eraser table, topmost selection, empty/canceled gesture history, partial trail selection, highlighter style/lifetime/Undo, new-tool permission rejection, AppleScript dictionary parity, fixed Deck identity/readiness and radial pagination/live history. Both Whole Line and Trail test expired-marker hit-testing. A status read that discovers expiration also notifies controls once, without waiting for the next clock tick or recurring through its own count query. Log: `/tmp/lhp-annotation-final-tests.log`. No compiler warnings in this final run.
- Swift test compiled the app and Deck executable locally with the unchanged SwiftPM Swift 5 language mode and macOS 13 target.
- Grid lint passed for MenuBarControls.swift, RadialMenu.swift and Toolbar.swift. Static HTML checks confirmed all eight inspector choices, including Cycle; AST parsing validated the replay script; the existing Choose Tool UUID remains `com.austinpresley.lookhereplease.choose-tool`. `git diff --check` passed.
- No UI automation, app installation, signing, notarization, packaging, hosted CI, PR, push or delivery ran. No normal preferences, real Hands or root untracked assets were changed.

Parent integration:
- Minimal Deck overlap is ToolChoice cases/symbols in KeyModel.swift and options/help in streamdeck/inspectors/choose-tool.html. No changes to DeckPlugin transport/queue or ControlBridge implementation. Merge these additions with independent pointer direction changes.
- Reconcile docs/control-protocol.md tool table and S-021 cycle description with the seven-tool list. Reconcile docs/streamdeck.md fixed-choice and saved-value lists with the same additions. Central story/glossary/fix/validation/milestone documents remain coordinator-owned.
- Pending acceptance remains integrated light/dark UI, narrow menu bar controls, two-page radial controls, screenshot appearance, real display crossing/mixed scales, actual sleep/lock, native Escape/text handling, Script Editor and physical Stream Deck/host inspector behavior. Intel and macOS 13 runtime checks remain pending. No simulated check establishes those hardware results.
- Display retention lasts for this running app session. Timed visibility continues while a display is unselected or Pointer is off; full geometry and semantic history remain recoverable. No disk document persistence or automatic wake activation is added.

Proposed glossary/copy additions:
- Eraser: removes one visible annotation per completed gesture. Undo restores it.
- Highlighter: translucent broad freehand annotation using the current ink controls.
- Copy for help: "Erase one annotation. Undo restores it." and "Highlight with the current color and drawing controls."
