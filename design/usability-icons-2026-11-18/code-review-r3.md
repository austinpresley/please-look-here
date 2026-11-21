# Icon-first implementation review, round 3

Verdict: **approve-with-notes**. All three round 2 P2 findings are fixed. One new, non-blocking P3 observer-registration leak remains.

Reviewed the uncommitted tree on `feature/usability-rethink-icons`, HEAD `8cbc20c`. Read `code-review-r2.md`, the round 2 fix entry beginning at `docs/VALIDATION.md:4156`, the affected implementation and regression tests. All 201 hashes in `dist/verification/usability-icons-fix2/source-manifest.json` match the current source, tests and scripts, including after the test run.

Only this report was authored. No source edits, commits, delegation, hosted CI, packaging, live-smoke or native input posting. The authorized test script created its normal build products and disposable fixtures. Findings below come from code tracing; no additional runtime probe was added.

## Status

| Item | Status | Verification |
| --- | --- | --- |
| R2-01: recovery metadata and journal disagreement | Fixed | `PresentationStore.swift:562` treats missing, unreadable or undecodable sidecars as hints and falls back to journal metadata. `:538` reads un-restored candidates sequentially, validates actual journals, records failures and selects the first readable copy independently of catalogue `problem` flags. `PresetsSettings.swift:40` uses this resolver, and `:124` refreshes selection after an Undo failure. Both Settings-model corruption tests pass, including damage after candidate selection. |
| R2-02: Suggested displays proposals for occupied commands | Fixed | `SuggestedShortcuts.swift:35` resolves the saved hold or chord for occupied commands; undecodable occupied values yield no invented assignment. `ShortcutsSettings.swift:63` displays the status, `:66` displays that resolved binding, and `:70` uses the same instruction for accessibility. The existing `SettingsModel.swift:108` main-queue Preferences observer publishes a revision after external edits. The Shift hold, custom chord, live Control change, cleared chord and malformed-value regression passes. |
| R2-03: favorite artwork and names remain stale | Fixed | `PresentationControls.swift:57` updates artwork by signature and tooltip/accessibility label by title. Both `Toolbar.swift:211` and `MenuBarControls.swift:207` call it on existing buttons. `Toolbar.swift:167` adds immediate custom-hand refresh; the popover refreshes while visible and when opened. The actual-button regression passes for rename, replacement and production artwork Undo, retaining button identities, frames and actions. |
| Undo candidate resolution across queues | Pass | Store/catalog availability is captured before dispatch. Catalogue and payload decoding execute on the utility queue; generation comparison and published state updates execute on main. Only summaries escape candidate resolution. Actual Undo reads the receipt off-main, then performs conflict checks and restoration on main. No new background UI access or queue-wait cycle found. |
| Observer ownership and leaks | Non-blocking note | Observer callbacks use weak owners and main-queue delivery. The new toolbar registration has no removal path. See R3-01. No new owner retain cycle found. |

## New finding

### R3-01, P3: the new custom-hand observer outlives its toolbar

Location: `Sources/TinyHand/Toolbar.swift:167`.

The block-based `addObserver` return value is discarded, and `Toolbar` has no observer cleanup. NotificationCenter retains that registration and its block after a toolbar is released. Capturing `self` weakly allows the toolbar to deallocate, but does not unregister the block. Each newly constructed toolbar therefore leaves another permanent, inactive registration. Repeated temporary overlays in the tests also construct toolbars.

Fix: retain both toolbar observer tokens and remove them in `deinit`, or use an owned subscription that cancels on release. Include the existing Preferences observer at `Toolbar.swift:166` in that cleanup.

This is P3 because production normally owns one toolbar for the application lifetime, and the retained registration does not retain the toolbar, panels or artwork. The pre-existing Settings-model observer cleanup omission at `SettingsModel.swift:108` and `:112` is unchanged by round 2 and is not a new regression.

## Concurrency and lifetime assessment

`resolvedRecoveryCatalogue()` does not collect full recovery receipts. Each failed decode unwinds before the next read; a successful receipt is reduced to a summary and returned immediately. The historical list remains metadata-only. Full journal validation checks paths and preference payloads without consulting mutable custom-hand membership: built-in asset mapping reaches `CustomHands.hand` with built-in IDs, which return before accessing its cache at `HandMaker.swift:425`.

`PresetsSettingsModel.refresh()` uses its generation only on main and rejects out-of-order completion results. Background work temporarily retains the model until completion, but the model owns neither the queued block nor a repeating task, so this introduces no retain cycle. `undo()` similarly returns to main before `store.restore`, catalogue reload and notification publication. Favorite signature/title state and image replacement stay in the controls' main-thread refresh paths.

These are static conclusions supported by the ordinary suite run, not a Thread Sanitizer or heap-instrumentation result. No new P0, P1 or P2 regression was found in the requested scope.

## Local test result

Ran `scripts/run-tests.sh` **once** on Austin's Mac. Reported suite start was 18 November 2026 at 21:27:04. The script supplied its own temporary defaults suite and Hands/Thumbnails directories.

| Check | Result |
| --- | --- |
| Swift Testing | 457 tests in 59 suites passed, 102.179 seconds |
| Round 2 regression suite | All four tests passed, 6.572 seconds |
| Native InputTap lifecycle | 24/24 installed, stopped twice and released |
| Python Stream Deck package test | 1 passed |
| Grid lints | 35 passed |
| Script exit | 0 |

No compiler warning, failing test or teardown abort was reported. No extra log file was created. Physical shortcuts, live desktop drawing/capture, VoiceOver traversal and macOS 13 runtime behavior were not exercised.

## Verdict

**approve-with-notes**. R2-01, R2-02 and R2-03 are closed. Clean up the new toolbar observer registration as a small follow-up.
