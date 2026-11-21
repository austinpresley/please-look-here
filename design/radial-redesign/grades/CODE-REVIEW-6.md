# Code review 6

Merge verdict: **request changes**. One P1, two P2s; no P0.

## Standards

- **P1**, `Sources/TinyHand/RadialMenu.swift:160`, `:164`: Held release/click bypass focus validation. Hold Option, Tab, select Clear, switch apps; completion before notification cleanup executes Clear and restores old focus. Production-method probes confirmed both routes. Fix: guard both with `cancelIfFocusLost()`; revoke keyboard-owned Hold on Command-Tab. Add delayed-notification release/click regressions, preserving pointer-only Hold and pair drainage.
- **P2**, `Sources/TinyHand/RadialSession.swift:170`: History refresh enables missing favorites named `clear`, `undo`, or `redo`. Probes accepted all three style activations. Fix: update validated history commands, rather than every group's matching ID; add collision regressions.

## Spec

- **P2**, `Sources/TinyHand/RadialMenu.swift:230`: Settings restores the external app before opening Settings. Delayed activation can steal Settings focus, repeating the browser's repaired race. Fix: transfer restoration into Settings and consume it on closure; test delayed activation.

Spec independently confirms both Standards findings.

Clean: persistent cancellation/generation rejection, recovery Command-Shift-U/Off/termination, browser transfer, AX slot identity/stale elements, reserved IDs/archive migration, capture exclusion and pair drainage. Five retained red regressions fail before fixes; all 177 manifest files match.

Validation: test rerun passes 382 tests/51 suites, Python and 20 grid checks; first run failed two issues. `swift build` and diff checks pass. Timing findings are source-traced. No live-smoke, posted input, normal-app access, commits or source edits.
