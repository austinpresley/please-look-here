# Icon-first implementation review, round 2

Verdict: **request-changes**. No P0 or P1 finding remains from round 1. Three P2 issues remain, including an incomplete recovery fix in the Settings caller.

Reviewed the uncommitted tree on `feature/usability-rethink-icons`, HEAD `8cbc20c`. Read the round 1 report, the fix entry in `docs/VALIDATION.md`, `UsabilityFix1Tests.swift`, all three phase manifests, and the relevant tracked diffs and untracked implementation files. The 200 hashes in `dist/verification/usability-icons-fix1/source-manifest.json` all match the reviewed source, tests and scripts. Earlier Quick controls v9, Settings and branding work remains in the tree; unrelated pre-existing changes are not findings here.

Only this report was authored. No source edits, commits, delegation, hosted CI, packaging, live-smoke or native input posting. The two authorized local suite runs created their normal build products and disposable fixtures. Failure scenarios below are established by code tracing, not live UI reproduction.

## Round 1 status

| Round 1 finding | Status | Code verification |
| --- | --- | --- |
| #1 P1: toolbar disappears inside tool picker | Fixed | `Toolbar.swift:76` grants a lease while the picker or palette is open. `OverlayController.swift:928` still gates visibility on pointer, toolbar, drawing and capture state. `Toolbar.swift:302` closes the picker on explicit hide. Both real picker rows, including the permission variant, are exercised after the deadline. |
| #2 P1: restored built-in artwork omitted from backup | Fixed | `PresentationArchive.swift:207` derives the exact built-in base filenames from the asset mapping. `PresentationStore.swift:201` exports those local files, and `PresentationArchive.swift:246` validates their PNG bytes and geometry. Existing import comparison at `PresentationStore.swift:230` rejects different local bytes. Staging tracks those paths and the recovery path validator accepts them. The regression exports, decodes, imports and compares actual replacement bytes, rejects a conflicting replacement, and removes the imported file on Undo. |
| #3 P2: Suggested Undo overwrites later shortcut edits | Fixed | `SuggestedShortcuts.swift:106` records only each successfully changed assignment key. `SuggestedShortcuts.swift:85` compares its current stored value with the recorded after-value before restoring the exact prior value or absence. Unrelated commands are untouched; conflicting later edits are retained and named. The regression covers both an unrelated Pen assignment and a later edit to the added hold trigger. |
| #4 P2: skipped suggestion cannot be retried | Fixed | `SuggestedShortcuts.swift:119` derives eligibility from current assignments and conflict checks, independently of the previous result. Clearing the conflicting assignment makes the row eligible again. |
| #5 P2: non-hand overrides cannot reset independently | Fixed | `PointerInspector.swift:71`, `:75` and `:81` expose separate resets for sound enabled, sound choice and Presentation shadow, with independent inherited/customized state. `PointerInspectorState.swift:35` clears only the requested optional field. The regression exercises actual edit/reset operations for all three non-hands. |
| #6 P2: broken historical recovery blocks Undo; listing eagerly loads payloads | Partially fixed | `PresetsSettings.swift:37` lists off-main and retains summaries. `PresentationStore.swift:536` uses small sidecars or bounded legacy reads, and the original broken-old/newer-valid scenario passes. However, the UI chooses its candidate from sidecar status rather than journal readability, so a new metadata failure can hide a valid journal. See R2-01. |
| #7 P2: permission button has a fixed accessible name | Fixed | `WelcomeWindow.swift:69` sets the accessible label from the freshly assigned native title. The native property test covers Show Pointer, Open Settings and Start Drawing. |
| InputTap teardown abort | Addressed in code; two full local passes | Retained weak-owner callback context, connection-only thread startup, serialized lifecycle, explicit owner teardown and event-loop drainage are present. Detailed assessment below. Both runs installed and stopped all 24 native taps without the previous abort. |
| Dead UI note | Fixed | The unused toolbar picker/drag, Sound-page and gesture-view trees and their unused drag/swap hooks are removed. Shared sound/artwork helpers and the embedded About page remain. Searches found no remaining references to the removed types/hooks. |

## P0

None found.

## P1

None found.

## P2

### R2-01: Optional recovery metadata can make a healthy journal inaccessible

Locations: `Sources/TinyHand/PresentationStore.swift:546`, `Sources/TinyHand/PresentationStore.swift:567`, `Sources/TinyHand/PresetsSettings.swift:40`, `Sources/TinyHand/PresetsSettings.swift:249`.

Failure scenario: save a preset, leaving its valid recovery JSON and new `.info` sidecar. If the sidecar later becomes truncated or unreadable while the JSON remains intact, the catalogue marks the entire copy as unreadable. Settings excludes it from Undo and disables its Restore button. With one copy, the page says there are no changes to undo even though `readRecovery(id)` and `latestRecovery()` can still decode the complete journal. The `.info` file has become an additional requirement for recovery, despite being only a metadata cache.

The inverse is also mishandled. With an intact sidecar and a damaged journal, the catalogue supplies `problem == nil`; Settings repeatedly selects that copy. `undo()` reports the decode error but neither marks the candidate unusable nor resolves another candidate. The robust payload-reading loop in `latestRecovery()` is not used by this UI.

Fix: treat sidecars as optional hints. A metadata error must leave a journal review/restore path available. Resolve the latest readable Undo candidate off-main, loading candidates sequentially and retaining only their summaries, and record actual journal failures without repeatedly selecting them. Preserve the lightweight historical list. Cover a healthy newest journal with a broken sidecar, and a broken journal with a healthy sidecar, through the Settings model. The existing tests exercise `PresentationStore.latestRecovery()` and a broken legacy JSON with no sidecar; they miss this caller mismatch.

Attribution: introduced by the fix round's catalogue and asynchronous Settings selection. Round 1 #6 is not fully closed.

### R2-02: Suggested teaches a different shortcut from the one already configured

Locations: `Sources/TinyHand/SuggestedShortcuts.swift:47`, `Sources/TinyHand/ShortcutsSettings.swift:63`, `Sources/TinyHand/ShortcutsSettings.swift:66`.

Failure scenario: configure Quick controls to use Shift, or give Pointer On/Off a chord other than the proposed Option-Command-P. Open Shortcuts. `isAssigned` correctly preserves the existing assignment and returns `alreadySet`, but the view hides that status and always renders `row.item.assignment`, the hard-coded proposal. It therefore visibly teaches Hold Option and announces "Hold Option to open Quick controls" even though Shift is the actual trigger. The Add count excludes this row, so applying Suggested will not make the displayed instruction true.

Fix: for occupied commands, show the actual saved assignment and a compact kept/configured state, or suppress the proposal and say the existing assignment is kept. Keep malformed/legacy occupied values protected without inventing a usable binding. Test an existing Shift hold and a non-proposed key chord against the row's visible and accessible instruction.

Attribution: the hard-coded proposal display was missed in round 1. The fix round's removal of the already-set status leaves no distinction between that proposal and the active binding.

### R2-03: Favorite buttons retain old artwork and names after editing the same pointer

Locations: `Sources/TinyHand/Toolbar.swift:195`, `Sources/TinyHand/Toolbar.swift:202`, `Sources/TinyHand/MenuBarControls.swift:193`, `Sources/TinyHand/MenuBarControls.swift:199`.

Failure scenario: let the toolbar and menu popover create their favorite buttons, then Restore Artwork for a healthy favorite such as Lavender using visibly different artwork. The pointer ID and favorite order stay unchanged. Both refresh functions rebuild the favorite images only when the array of pointer IDs changes. Subsequent refreshes update selection state, not those images. The actual overlay and Settings inspector refresh their artwork, but the icon-only quick controls still display the old hand. Renaming a custom favorite similarly leaves the old tooltip and accessible button name in these controls.

`HandAsset.forget` does not update an `NSImage` already retained by a button. `Toolbar.icon(for:)` supplied a rendered thumbnail at button creation. Closing and reopening the popover does not rebuild an unchanged catalog.

Fix: invalidate favorite presentation when artwork signatures or titles change, updating each existing button's image, tooltip and accessible label while retaining its frame and action. Test an in-place artwork replacement and a custom-hand rename with unchanged favorite IDs. Include Undo of the artwork replacement.

Attribution: redesign integration gap missed in round 1, exposed by the new Restore Artwork and rename actions.

## InputTap lifetime assessment

The new lifetime structure addresses the observed unsafe ownership pattern:

- `InputTap.swift:112` creates a separate `CallbackContext` with a weak owner and passes a retained context to native code. Failed `tapCreate` releases that retain at `:129`. The callback's weak load acquires a temporary strong owner before handling an event, so native code never dereferences an unretained `InputTap`.
- `InputTap.swift:178` captures only `NativeConnection` in the thread. The connection owns the tap, source and run loop, and holds no strong `InputTap`. There is no startup weak-self load that can release a resurrected owner during deinit.
- `install()` and `stop()` serialize connection ownership with `lifecycleLock`. Tap and input state remain under the state lock. `stop()` releases the state lock before waiting for the event thread, allowing an in-flight handler to finish. The production handler dispatches UI notifications asynchronously rather than waiting for main, avoiding a main-thread-stop/event-thread-main-queue join cycle.
- Off the event thread, `NativeConnection.stop()` schedules invalidation on its run loop and waits for `exited`. Cleanup releases the retained context at `:185` before leaving the group. Repeated owner `stop()` calls have no remaining connection to stop.
- On the event thread, final temporary-owner release can run deinit. The explicit same-loop branch at `:200` invalidates inline and avoids joining itself. Context release happens after the callback returns and the run loop unwinds. This is the intentional exception to the comment's blanket claim that callback drainage finishes before every `stop()` return.
- `OverlayController.swift:289` explicitly stops its tap during owner teardown. The parameterized mode/tool test now uses the injected installation operations, while a separate bounded test checks real native lifecycle.

I found no new retain cycle or deadlock in these production lifecycle paths. The two full runs support stability of ordinary installation/teardown; they do not prove every concurrent schedule or the callback-thread final-owner branch. The lifecycle test checks owner release and disabled/uninstalled state, not an instrumented count of live callback contexts. The injected restart test also does not enqueue callbacks despite its name. These coverage limits do not reproduce the prior abort and are not separate blocking findings.

The built-in artwork fix also holds up beyond its inclusion strings: exact canonical names, byte comparison, staging context checks and recovery validation all apply to the restored base file. I found no remaining omission or overwrite in that export/import path. Suggested Undo's changed-key and after-value checks are likewise implemented in the production path, not just in a test helper.

## Local test results

Ran the full `scripts/run-tests.sh` twice, sequentially, on Austin's Mac. Each invocation supplied its own temporary defaults suite and Hands/Thumbnails directories.

| Run | Reported suite start, 18 November 2026 | Swift result | Native InputTap lifecycle | Python package test | Grid lints | Exit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 21:03:44 | 453 tests in 58 suites passed, 97.736 seconds | 24/24 installed, each stopped twice and released | 1 passed | 35 passed | 0 |
| 2 | 21:06:00 | 453 tests in 58 suites passed, 95.983 seconds | 24/24 installed, each stopped twice and released | 1 passed | 35 passed | 0 |

Neither run aborted or reported a failing test. These are fresh review runs, separate from the three implementation runs recorded in `docs/VALIDATION.md`. No additional log file was created because this review permits only this report as a new authored file. The previous failed full run remains recorded in round 1 and is not erased by these passes.

No packaging, live desktop input, physical shortcut, VoiceOver traversal or macOS 13 runtime verification was performed in this review.

## Verdict

**Request-changes.** The original two P1 defects and the InputTap teardown failure are addressed. Close R2-01 so the recovery UI can use a valid journal independently of its metadata cache, and correct the two P2 cases where icon-first controls display information that no longer matches the saved pointer or shortcut.
