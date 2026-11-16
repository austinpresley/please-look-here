# Input and cycle review implementation

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-f3ec5cf9`.
Branch: `t3/hotkey-input-cycle-reliability`.
Scope: S-038, S-039, S-043. Swift 5 language mode and macOS 13 remain unchanged.

## S-038

Implemented a 180 ms bare-modifier hold deadline in the existing radial router.
Earlier mouse downs, ordinary keys, extra modifiers, release, scroll, eligibility
loss and closure cancel the pending opening. Mouse movement updates its origin.
Native modifier flags are sampled at the deadline and on configuration/service
refresh, including while closed. A sampled missed release cancels stale UI,
clears the held latch and increments `reconciledReleases` diagnostics. Existing
claimed button/Escape pairs survive closure, deactivation and trigger clearing.

Local evidence: `swift test --filter RadialTests` passed 15 tests. Tests exercise
179/180 ms boundaries, early native mouse/key pairs, closed/open missed-release
reconciliation and retained Escape/button ownership. Existing controls/lock
routing tests now explicitly advance the hold before checking pair ownership.
All commands use `TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.inputcycle.unit`
and `TH_HANDS_DIR=/tmp/lhp-inputcycle-unit-hands`.

The historical reopen root cause remains a hypothesis. No native physical input,
UI automation, normal app preferences, signing, install or packaging was used.
Parent must verify the real modifier timing, release recovery and panel behavior.

Copy proposal: "Hold the modifier alone briefly to open. Clicks and key chords
before the menu opens keep their usual behavior." No new glossary term needed.
