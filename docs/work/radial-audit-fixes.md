# S-038 radial source-review corrections

Date: 15 November 2026

Worktree: `/Users/apresley/.t3/worktrees/Please Look Here/t3-b0ab5ba2`

Branch: `t3/radial-session-key-state-fixes`

Starting commit: `3257863f0da56a9982000342eff10b552e8d7491`

## Findings and fixes

The first review's two P2 findings reproduced in focused tests before the fixes.

1. A queued close from gesture A called the unscoped `RadialInput.end()` after gesture B began. B's pending hold disappeared. Each queued open, move, release, click and cancel now carries its originating session ID. `end(sessionID:)` changes input state only for that ID. OverlayController rejects an obsolete open; RadialMenu applies move, release, click and cancel only to its matching displayed session. Menu close callbacks return that displayed ID, including the display-too-small failure path. Explicit application dismissal can still close the current menu.
2. `keys` represented consumed Escape ownership, so a native ordinary key held before the trigger did not block opening. `heldKeys` now records observed keyboard state independently of owned pairs. InputTap observes down/up before routing to other owners. Hold creation and completion also sample native ordinary-key state, covering a key already down before tap installation and a down missed during the hold. Hardware modifier key codes are excluded from that sample. Ordinary down, repeat and up keep their original event object, flags and repeat value.

The callback audit found another generation gap in the hold timer. Its initial pending-ID check preceded native state sampling, then `advanceHold` could operate on a newer gesture. The transition now checks the expected pending ID under its own lock before reconciling flags or opening. A stale timer cannot cancel B using A's sampled release, or advance B using A's deadline callback.

Tap re-enabling discards ordinary-key observations that may have missed releases while disabled. Native sampling covers keys still physically held. This reset preserves swallowed Escape and mouse ownership. Observed ordinary keys alone never keep the tap enabled.

The hold remains 180 ms. Trigger assignment, existing shortcut values, bundle identity, saved preferences, Hands and Stream Deck profiles are unchanged. Changes in RadialMenu are limited to callback/session routing; its sound command, pointer configuration lookup, controls and raw values are unchanged.

## Local evidence

All commands ran on Austin's Mac in this worktree. Each test/build invocation used a separate temporary data root with isolated `TINYHAND_DEFAULTS_SUITE`, `TH_HANDS_DIR` and `TH_THUMBNAILS_DIR`. Radial tests inject a fixed native key-state function and directly route synthetic CGEvents without installing a tap or posting input.

Before changing production sources:

```sh
swift test --filter 'RadialTests/(delayedPreviousCloseCannotClearNextPendingHold|ordinaryKeyHeldBeforeModifierPreventsOpeningAndPassesUnchanged)'
```

Result: both tests failed, with three failed expectations. A's delayed release/close cleared B's pending state and prevented B opening. Space down before Option produced `open == true` at the hold deadline. Local log: `/tmp/radial-audit-red.log`.

After the fixes and expanded regressions:

```sh
swift test --filter RadialTests
swift build --product TinyHand -v
scripts/grid-lint.sh Sources/TinyHand/RadialMenu.swift
git diff --check
```

Results: 22 tests passed, including parameterized cases, local product build passed, grid lint passed and the whitespace check passed. Local logs: `/tmp/radial-audit-expanded.log` and `/tmp/radial-audit-build.log`. SwiftPM used the installed Apple Swift 6.4 compiler; the package remains in Swift 5 language mode, and generated build commands retain the app's `arm64-apple-macos13.0` deployment target. `Package.swift` is unchanged.

Regressions cover:

- Delayed A release, click and cancel close callbacks while B is pending. Open/move/terminal notifications retain A's ID; B still opens. Another stale A close also leaves an already-open B intact.
- An old timer with either released or held modifier flags leaves B pending and held. B's own timer opens it.
- Space held before the modifier, prior to autorepeat, blocks opening and requires a fresh modifier press after release.
- Sampled native keys 0, 49, 53, 64 and 127 block opening without any observed keyDown, and a sampled down during the hold also blocks completion.
- Native modifier key-state samples permit an otherwise bare-modifier hold.
- Ordinary keyboard event identity, modifiers and autorepeat pass through InputTap unchanged; unowned observations do not retain tap ownership.
- Re-enabling after a missed ordinary key release permits a new hold while owned Escape repeats/up still drain.
- Existing early mouse/key/scroll cancellation, 179/180 ms boundary, sampled modifier-release recovery, drag rejection and owned mouse/Escape pair regressions still pass.

No GUI or native-input validation, application installation, release signing, notarization, packaging, hosted CI, pushes, PRs or deliveries were performed. The combined suite was left to the parent because other suites construct native UI or install event taps. The parent owns integrated validation and packaging.

## Parent acceptance still needed

Verify actual native key-state sampling with Space held before enabling the radial tap, Space then assigned modifier before repeat, and rapid successive gestures while main-queue menu work is delayed. Check all assigned modifiers, ordinary chord delivery, the displayed menu's scoped move/release/click/cancel behavior, and retained Escape/mouse releases across dismissal or deactivation. Run integrated UI checks and release validation after merging.

These fixes close the two reproduced source gaps. The historical reopen failure still has no established causal link to either gap, so this evidence does not close that original report.

## Glossary and copy proposals

- Proposed glossary term: **radial input session**, the generation attached to one pending hold and its queued menu callbacks. It is distinct from `RadialSession`, which owns menu geometry and candidate selection. Owned press/release pairs can outlive the input session.
- Proposed glossary term: **observed ordinary key**, a held native key that prevents a bare-modifier gesture without giving the app ownership of its down, repeats or up.
- No user-facing copy changes proposed.
