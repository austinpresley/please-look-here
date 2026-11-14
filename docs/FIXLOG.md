# Integration fixes

## S-013 reopen diagnosis, unresolved

The prior full native run failed when reopening for the other-button case after a
claimed right-button press/release cleared and reassigned the trigger. Retained
callback totals show that the right-button pair arrived and the other-button pair
never began. Two user-input-disabled notifications arrived in that interval.
The retained state was captured after cleanup, so it cannot identify the missing
transition or prove a latch, tap-recovery, main-queue or runner cause.

The focused review adds test diagnostics and a bounded same-process native stress
mode. Every opening checks callback delivery, native flags/buttons and both logical
and Window Server visibility. Failure state is captured before modifier cleanup.
A missing eligibility/enabled prerequisite fails explicitly before opening Option;
there is no readiness wait, repost or app restart. Unrelated popup-level windows
were proven to block two initial setup attempts and were removed. Those setup
failures are separate from the retained case and do not establish its cause.

No production fix is claimed. Successful repeated native scenarios bound the
verified scope; they do not prove absence of an intermittent failure. Keep S-013
implemented/review and the reopen risk for coordinator review. Commands, results
and preserved round delta are in `dist/verification/s013-reopen-review/`.

Rule: preserve event callback and native input state before test cleanup; a later
enabled tap and cleared modifier cannot reconstruct the failed transition.

## S-013 claimed Escape autorepeat ownership

Symptom: Escape dismissed the radial and consumed its initial down and release,
but autorepeat downs reached the underlying app while the key was still held.
The routing regression failed twice with six assertions across cancellation,
trigger clearing and deactivation. The native fixture received three repeat downs
and no release from the owned sequence on installed build 20261110185016.

Cause: `RadialInput` checked its owned-key set only for keyUp. After the first
Escape cancelled the menu, subsequent keyDown events took the ordinary-key path.
Ownership was still recorded and the tap was still enabled.

Fix: check recorded ownership before handling a keyDown. Keep it until the
matching keyUp removes it, independent of menu visibility, eligibility or trigger
assignment. The regression calls the actual `InputTap.handle` route with
`keyboardEventAutorepeat=1`; the guarded native loop checks fixture-received key
counters and also proves an ordinary modified key's repeats and release pass.
Fresh evidence is in `dist/verification/s013-review-fix/`. Earlier S-013 evidence
remains historical and unchanged.

Rule: input ownership covers every repeated down through the matching release;
closing a UI or changing its configuration does not end a claimed key press.

## Toolbar dragging and event-tap recovery

The native fixture check exposed delayed AppKit move notifications. Saving the cached origin immediately after `performDrag` could save an intermediate point. The toolbar now records final WindowServer geometry and subsequent move notifications. Drag persistence writes do not trigger a toolbar relayout. Resizing the tool row preserves the stored bottom origin, and Reset Position clears the preference and recenters the panel.

The same check exposed repeated event-tap enable calls inside disabled-by-user-input notifications. A local process sample showed `SLEventTapEnable` inside the event callback. Re-enabling is now conditional on the real enabled state; system-input pauses retry from the bounded UI service tick. The regression run completed with 128 input callbacks, including ten disabled notifications, rather than the earlier flood.

Rule: save completed window geometry after the system moves it, and never recursively re-enable a tap from its user-input-disabled notification.

## Shortcut reservations

Common editing shortcuts, Settings, Undo and Redo are reserved for app-window commands. Presentation commands, including annotation Undo/Redo and Open Settings, use optional user assignments. Unit tests cover reservations, empty defaults, saved assignments and clearing.

Rule: validate configurable shortcuts against native app commands as well as other assigned bindings.

## S-016 floating toolbar visibility

Symptom: Show toolbar was off, but turning the pointer back on could leave an
opaque floating toolbar onscreen. Status incorrectly reported it hidden.

Cause: `hide()` cleared a cached `revealed` flag without clearing panel opacity.
Activation unconditionally ordered the panel forward. `setRevealed(false)` then
returned early because that flag already said hidden. Permission recovery also
bypassed the preference, and enabling through Settings did not restart the reveal
deadline after it had expired.

Fix: reconcile alpha, mouse handling and native ordering in one panel method;
derive reported visibility from the actual panel. Route activation, preferences,
hover and permission recovery through the same preference gate. Enabling starts
the existing three-second reveal; disabling always hides. The regression asserts
both logical state and the native panel through the real activation sequence.

Rule: a cached visibility flag must never replace native window state as the
assertion. Every reveal path must respect the user's saved visibility choice.


## S-013 native radial dismissal and test-window compatibility

The first toolbar regression run inspected the radial panel because a new window
was inserted before the toolbar in `windowsForTesting`. The existing three tests
went red with six assertions. Appending the new window preserves that interface;
the same focused tests and full suite pass. Rule: preserve existing test-window
ordering when adding a panel.

Native `extended-smoke.py` then caught `radial.visible=false` while Window Server
still reported radial window alpha 0.2216. The default AppKit panel dismissal was
animating after `orderOut`. Disable automatic animation on radial/result panels;
verify actual Window Server absence/opacity as well as app state. The first light
capture also exposed dark resolved CALayer backgrounds under light-mode labels.
Resolve layer colors under the panel's effective drawing appearance. Rule: native
visibility and effective appearance must be measured at the displayed window.


An overlapping-button regression test then went red with two failed assertions:
a second button passed after the first radial click closed the menu. Keep new
button presses in the same owned gesture until every claimed release drains.
Enabling a trigger while its modifier is already held also starts latched, using
current session flags, and requires release before a fresh gesture. Rule: closing
a control does not end ownership of an unfinished native button gesture.
