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
