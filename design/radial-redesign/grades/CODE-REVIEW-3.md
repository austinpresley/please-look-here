# Code review 3

Merge verdict: **request changes**. One P1 remains; no P0 or P2 found.

**P1: reopening the wheel permits another early restoration.** `Sources/TinyHand/ClearRecovery.swift:160`, `Sources/TinyHand/RadialMenu.swift:186`. Focus recovery, release Hold, click the external app, reopen the wheel, Tab into it, then focus recovery again. Recovery retains `tookFocus` after resigning key, so its second `focus` skips `takingRestoration`. The new wheel retains its own restoration token and `tookFocus`. Releasing Hold closes that wheel and activates the external app, stealing Undo focus again. Persistent-mode closure has the same defect. The eligibility guard blocks reopening while recovery is key, but permits it after external focus resumes.

Fix: evaluate `takingRestoration?()` before `if !tookFocus`; adopt its result only when recovery lacks an existing obligation. This executes the wheel's relinquishment callback on every handoff while retaining recovery's original token. Add held/persistent two-session regressions. An isolated probe using current ClearRecovery source confirmed one transfer callback for two focus requests, focus lost upon the second wheel's restoration, and two restoration calls after Dismiss.

Checked clean: first-session Undo/Dismiss, queued Hold cancellation, focused invalidation, stale Undo rejection, capture with/without edits, persistent transfer, refresh suppression, and ownership cleared before restoration callbacks. Saved-app termination is guarded by `isTerminated`; dead weak windows/responders are tolerated. External focus behavior was source-traced, without native input.

Reviewed saved pre-transfer/current source differences, requested files, focus helper, production responder/menu wiring and new tests. Retained red logs confirm all five regressions and all 13 cases failed before the fix, totaling 97 expectations.

Local validation passed: 370 tests/51 suites, one Python test, 20 grid checks, `swift build`, and `git diff --check`. Only this report written; no installed-app access, commits or live smoke.
