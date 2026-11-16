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
