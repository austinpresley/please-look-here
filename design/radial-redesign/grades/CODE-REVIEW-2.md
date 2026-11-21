# Code review 2

Merge verdict: request changes. One P1 remains; no P0 found. Reviewed the scoped diff and untracked source/tests, including HUD, responder, routing, AX and wrapping changes, with the requested exclusions.

Round-1 verification:

- Persistent click-through: **fixed**. InputTap installs and confirms enablement before opening, rejects connection failures, and drains dismissal pairs. The installation/enable/order/failure regressions would fail if this behavior were removed.
- Stale AX actions: **fixed**. Live generation, level, epoch and item-ID validation rejects retained press/focus actions before another refresh. Reset clears children. Both stale-element regressions would fail against previous behavior.
- Annotation Undo/recovery: **partial**. Scoped selectors/equivalents and text-field exclusions work, but focus handoff fails. Responder tests detect missing handlers, not disconnected production wiring. External Command-Z passthrough already passed before the fix; no unit test exercises recovery focus/restoration.
- Screenshot restoration: **fixed**. Capture closes wheel/list/browser, cancels handoff, retains exclusion IDs, drains pairs and restores only revision-valid recovery. Transport regressions fail against session restoration; browser/window closure assertions exist in the separate snapshot script, outside run-tests.sh.

**P1: releasing Hold takes focus away from Clear recovery.** `Sources/TinyHand/RadialMenu.swift:159`, with `RadialInput.swift:195` and `ClearRecovery.swift:160`. With an external app frontmost and valid Clear recovery visible, hold Option, use Tab to give the wheel keyboard focus, then Command-Shift-U to focus recovery. Release Option. Native recovery focus makes RadialInput cancel the held session; RadialMenu.close still sees tookFocus and activates the original external app. Recovery loses keyboard focus, and Return intended for Undo can reach that app. Recovery saved the wheel/current app rather than the original restoration context.

Fix: transfer the original app/window/responder restoration context to recovery. Closing the wheel must restore focus only while it still owns it; recovery restores the transferred context when finished. Add a regression covering held opening, keyboard transfer, recovery focus, trigger release, queued cancellation, Undo and app restoration. The held-focus test never releases the trigger or constructs either window.

Checked clean otherwise: external Interact Undo routing, text undo, AX viewport geometry, touched lock/callback ordering, capture exclusion, persistent nonactivating error presentation and announcement deduplication, measured hyphenation/soft-hyphen removal/composed-character wrapping, frozen favorites and local-only tooling.

Local validation passed: 365 Swift tests/50 suites, one Python test, 20 grid checks, swift build and git diff --check. No native input, live smoke, installed-app access or commits. Only this report written. External focus behavior was traced in source, not reproduced with native input.
