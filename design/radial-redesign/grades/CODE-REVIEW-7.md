# Code review 7

Merge verdict: **approve-with-notes**. One non-blocking P2; no P0/P1 found.

- **P2**, `Sources/TinyHand/RadialArtwork.swift:9`, `:35`, `RadialLayout.swift:80`: Imported, valid missing favorites named `pointer`, `color`, `draw`, or `interact` still inherit root-command presentation through bare-ID checks. Pointer-level entries show the current pointer/swatch/tool; `interact` shows an OFF badge. Fix: qualify root artwork, badge and check rules by root level and slot or explicit semantic role; pass that identity into row-state rendering. Add wheel/list collision regressions. An in-memory probe of the production functions confirmed the artwork/state mismatch. Activation remains disabled.

Round-6 fixes verified: release/click synchronously check key-window and app ownership; Command-Tab revokes keyboard-owned Hold and queued activations while draining claimed pairs; pointer-only Hold still selects over an external app. History updates validate fixed level/slot/ID/operation. Press matching includes level/slot/ID; AX adds generation/epoch. Settings receives and consumes the original restoration once. The flaky lifecycle fixture injects menu sampling; production sampling and a positive external-menu regression remain.

Checked retained pre-fix source/red logs for every reported repair, including menu replay, press matching and command preparation. Their failing assertions remain in current tests. All 177 manifest files match.

Whole-change sweep clean for P0/P1: tap enablement, queued-event rejection, recovery transfers/Undo/Off/quit, browser handoff cancellation, capture exclusion and pair drainage, favorites/archive migration.

Local validation: both runs passed 391 tests/51 suites, Python contract and 20 grid checks; `swift build` and `git diff --check` passed. Native focus was source-traced. Only this report written; no posted input, live-smoke, commits or normal-app access.
