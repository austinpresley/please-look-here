# Integration fixes

## S-026 queued audio and context cancellation

Audio engine/device calls could block the main thread during screen sharing.
They now run on a serial audio queue, recreate the engine after configuration or
render failure, and use multiple player nodes. Review also reproduced cancellation
during first engine startup and after a tap had already entered the audio queue.
Recheck the ticket after startup, invalidate it on presentation context changes,
and reconcile direct mode changes such as permission-driven Draw-to-Point fallback.
Blocked-driver regressions fail before and pass after each correction.

Rule: cancellation belongs to the queued operation as well as its UI scheduler;
recheck it after any blocking call and reconcile every state-change route.

## S-027 lock fallback keeps complete owned pairs

The first lock backstop discarded every stored owner. Review regressions showed
an unrelated captured mouse/key release leaking after a forwarded unlock press.
An owned Escape autorepeat could also delete its owner before the matching up.
Forward fresh system presses, relinquish only their matching old owner and retain
unrelated pairs and already-owned repeats through release. Controls close without
committing a canceled status click. Drawing, controls and radial regressions pass.

Rule: a lock transition does not turn an owned autorepeat into a fresh press or
end an unrelated pair's release ownership.

## Native press ends over app controls

A Point press starting in another app could end over our toolbar or Settings.
The local mouse-up was filtered out with other own-window input, leaving the hand
held and blocking gesture eligibility and idle motion sleep. Own-window Point
releases now finish the visual press too. The DEBUG observation regression failed
before the fix and passes afterward; annotation routing remains separate.

Rule: an owned surface boundary cannot erase the release of a visual press that
started outside that surface.

## S-032 unusable gesture artwork releases its shortcut

An external corrupt or incompatible pose image could leave its exclusive shortcut
registered while every pose attempt was rejected. Registration now requires a
decodable pose; image signature changes reconcile registrations even without an
active pose. Stored assignments survive, and restoring artwork re-registers them.
The native corruption/restoration check verifies both registration counts.

Rule: an unavailable optional action must not retain an exclusive key merely
because a saved assignment exists.

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
# App review screenshot recovery, 15 November 2026

Symptom: screenshot frame, display or encoding failures could offer Screen
Recording settings even when access was already allowed. Success feedback gave
only a filename and could not reveal or copy the saved image.

Cause: recovery checked whether the error belonged to the entire ScreenshotError
enum, rather than its permission case. Success used a noninteractive toolbar hint.

Fix: classify permission recovery separately from Retry, dispatch retries after
capture cleanup, and present one interactive result panel retaining the latest
encoded image. Region retry starts a fresh cancellable selection.

Rule: choose recovery from the actual failure and keep completed capture actions
separate from taking a new screenshot.
# App review corrections, 16 November 2026

## Display documents and faded ink

Crossing displays reset the complete annotation document and history. Layer-only
fading left invisible markers selectable and text without the same fade policy.
DisplayInkStore now owns documents by stable display ID. InkVisibility owns
captured lifetimes separately from full geometry/history, and erased/expired
objects are excluded from hit testing. Native off/on and expired-marker checks
pass; physical display crossing remains a separate hardware limit.

Rule: presentation visibility changes must not implicitly destroy semantic history.

## Radial callbacks and ordinary chords

Immediate modifier opening captured ordinary clicks. Delayed callbacks could also
close a newer gesture, and key-first chords were not considered. A 180 ms pending
hold now cancels for early native input. Queued events and timers carry session
identity; ordinary held keys are observed/sampled without becoming owned pairs.
Fixed clocks and injected schedulers keep unit timing independent of real input.

Rule: retain ownership through matching releases, and scope every deferred action
to the gesture that created it.

## Shortcut registration

One unavailable combination unregistered unrelated commands. HotKeyBindings now
retains each successful binding independently, retries failures separately and
shows command-specific conflicts without changing saved assignments.

Rule: one command's registration failure must not determine another's lifetime.

## Hand recovery and manifest loading

Removal was permanent. The new file receipt originally allowed receipt corruption
to hide valid manifest membership, and finalized Undo before preferences persisted.
Loading now retains validated membership and blocks mutations after failed
recovery. HandRestoreTransaction keeps restoration replayable through checked
preference persistence and completion. Overrides merge only the removed ID.

Rule: a failed load is never an empty writable library, and recovery is complete
only after both file and preference phases succeed.

## Import ownership and publication

Importing a removed identity could consume an unrelated removal journal and restore
unpreviewed gestures. Background file writes also left a gap where accepted edits
could be overwritten. Preview now rejects pending removal IDs. Heavy preparation
runs off-main; final validation/publication shares the app writers' main queue,
with a journal published before canonical changes and retryable rollback.

Rule: validate the same context at the shared publication boundary, and never
silently take ownership of another operation's recovery record.

## Sound output ordering

Rapid mute/unmute could make queued gain updates both see the final positive gain,
leaving already scheduled audio alive. The silent transition now retains its own
teardown while subsequent gain updates use the latest output. Queue-order tests
use separate injected deadlines; real watchdog tests keep the production timer.

Rule: later output state cannot erase an earlier cancellation request.

## Native preview and shortcut navigation

Active captures caught a 256-point preview control row, truncated segmented text
and a dark-mode sample whose renderer could keep zero bounds. Intrinsic controls
are bounded and labeled accessibly; the renderer lays out on attachment/resize.
Local ink publishes control state without replacing another observer.

Practice links initially opened Shortcuts before the target row completed layout.
SettingsHostingView now reveals and focuses stable native destinations after
mounted layout, without starting recording. Ordinary navigation cancels stale
requests. Native Pointer, Pen, Interact and radial link checks pass.

Rule: UI completion requires native layout and responder evidence, rather than
source-only navigation or delayed guesses.
