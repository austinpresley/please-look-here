# Code review 4

Merge verdict: **request changes**. Two P2 findings; no P0/P1.

- **P2: browser handoff can lose the original context.** `Sources/TinyHand/RadialMenu.swift:175`, `Sources/TinyHand/OverlayController.swift:346`, `Sources/TinyHand/PointerBrowser.swift:261`. Open persistent controls from another app, then click All pointers. Closing the wheel consumes its token and requests external activation; the browser waits only for input drainage, then recaptures frontmost app/window/responder. Activation need not have completed, so it can save our app instead and never return to the original app on close. Fix: transfer the wheel token through the pending handoff into the browser without restoring/recapturing; restore once on cancellation or browser close. Add delayed-activation/cancel regressions.
- **P2: graceful quit abandons recovery's token.** `Sources/TinyHand/AppDelegate.swift:100`, `Sources/TinyHand/OverlayController.swift:535`. Focus recovery from the wheel, close that wheel, then quit. Termination calls only `deactivate`, which never dismisses recovery; its original restoration action is never consumed. Fix: explicitly dismiss recovery during termination before deactivation, including when already inactive; test one restore and repeated cleanup.

Round 3 is fixed. Every valid handoff relinquishes the wheel token; recovery keeps the first. Later tokens have no remaining owner or restoring destructor. Source-traced arbitrary repetitions, unfocused-recovery wheel closure, list/persistent ownership, capture, invalidation, failed focus, stale Undo, dead weak responders and terminated saved apps. HUD appearance acquires no restoration obligation. Verified retained 36-failure red evidence and current regressions.

Local validation passed: 372 tests/51 suites, Python contract, 20 grid checks, `swift build`, `git diff --check`. Only this report written; no native input, live smoke, installed-app access or commits. Timing findings are source-traced.
