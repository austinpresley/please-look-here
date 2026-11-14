# Selected fork upgrade code review

Baseline: local review checkpoint `8451227`. Feature commits begin at `0f0be21`; final cancellation reconciliation is `a96036c`. Austin authorized routine decisions while sleeping, so the coordinator selected the exact pre-change checkpoint and local spec rather than requesting an external issue-tracker setup. Reviews were read-only and split between project standards and the selected scope.

## Standards

### Initial findings

- [P2] Recheck cancellation after audio startup in [TapSound.swift:143](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/TapSound.swift:143>). `play()` validates its ticket before `playNow()`, but `start()` can block. If mute, deactivation or shutdown invalidates the ticket during startup, execution still reaches `driver.play`; queued teardown runs afterward. This breaks the documented sound-cancellation contract in [integration notes:60](</Volumes/Project-Vault/PROJECTS/Please Look Here/docs/research/fork-upgrades-integration-notes-2026-11-14.md:60>). Pass the ticket into `playNow()` and revalidate after startup, before scheduling the buffer.

- [P2] Gate gesture hotkey registration on decodable artwork in [AppDelegate.swift:209](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/AppDelegate.swift:209>). Registration checks only `assetName`. If imported artwork becomes corrupt or has incompatible dimensions, the exclusive hotkey remains registered while `beginGesture()` rejects every press. The shortcut is swallowed without showing a pose. This breaches the explicit “Register only assigned, decodable poses” rule in [integration notes:50](</Volumes/Project-Vault/PROJECTS/Please Look Here/docs/research/fork-upgrades-integration-notes-2026-11-14.md:50>). Validate each slot before registration and refresh registrations when artwork availability changes.

### Second review

Both prior findings are resolved. Two documented-standard breaches remain:

- [P2] Cancel queued audio on context changes in [OverlayController.swift:655](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/OverlayController.swift:655>). If audio startup blocks after `tapSound.play()`, changing mode/style or opening controls cancels only the contact scheduler and animation. The audio ticket stays valid, so playback proceeds after startup despite cancellation. Invalidate the audio ticket at this boundary using `tapSound.silence()` or equivalent. This violates the context/style/mode cancellation contract in [integration notes:60](</Volumes/Project-Vault/PROJECTS/Please Look Here/docs/research/fork-upgrades-integration-notes-2026-11-14.md:60>).

- [P2] Preserve owned Escape autorepeats during lock fallback in [InputTap.swift:159](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/InputTap.swift:159>). If controls or radial input captured Escape before locking, its next autorepeated down enters this branch. `suspendForSystem(key:)` deletes its owner, then forwards the repeat and matching release although the initial down was swallowed. Distinguish fresh system presses from owned autorepeats and retain the latter through keyUp. This violates the explicit repeated-down ownership rule in [FIXLOG.md:48](</Volumes/Project-Vault/PROJECTS/Please Look Here/docs/FIXLOG.md:48>).

### Permission fallback follow-up

- [P2] Cancel queued audio on permission-driven mode changes in [OverlayController.swift:781](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/OverlayController.swift:781>). When Accessibility is lost during Draw, `checkPermission()` sets `.point` directly, bypassing `setMode()` and its cancellation. Presentation shortcuts remain eligible, so this new guard also skips cancellation. A drawing tap queued behind blocked audio startup can consequently play after the forced mode change. Cancel feedback in the permission fallback or centralize cancellation during mode reconciliation, and extend the blocked-start regression to cover permission loss. This breaches the mode/context cancellation rule in [integration notes:60](</Volumes/Project-Vault/PROJECTS/Please Look Here/docs/research/fork-upgrades-integration-notes-2026-11-14.md:60>).

The round-one findings and owned-Escape repeat finding are resolved.

### Final result

Clean at `a96036c`. The permission-fallback objection is resolved: [mode reconciliation](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/OverlayController.swift:334>) invalidates queued audio before input/state updates, including recursive Draw-to-Point fallback.

The [regression](</Volumes/Project-Vault/PROJECTS/Please Look Here/Tests/TinyHandTests/AudioTests.swift:132>) forces the actual permission fallback while startup is blocked and checks that playback never occurs.

No remaining material Standards breach found in this follow-up.

## Spec

### Initial findings

Two findings in the pinned `8451227...e5bc659` diff:

- **P2: Cancellation is not rechecked after audio startup.** S-026 requires audio operations to “stop cleanly.” A tap can pass the gate, block inside `start()`, then schedule playback after mute or deactivation has canceled its ticket. Queued teardown runs afterward. Recheck the ticket after startup, before `driver.play`. The existing blocked-device test queues playback behind `warm()`, so it misses this case. [TapSound.swift:143](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/TapSound.swift:143>), [AudioTests.swift:80](</Volumes/Project-Vault/PROJECTS/Please Look Here/Tests/TinyHandTests/AudioTests.swift:80>).

- **P2: The lock fallback discards unrelated captured releases.** S-027 says “Captured releases drain safely.” Any locked-session key-down or mouse-down clears every drawing, controls and radial pair owner. For example, a captured drawing press followed by a locked-session key-down loses its owner, so its eventual mouse-up is forwarded without its corresponding down. Forward the unlock press while retaining ownership for unrelated outstanding pairs. [InputTap.swift:159](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/InputTap.swift:159>), [ControlInput.swift:19](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/ControlInput.swift:19>).

No clear unasked feature scope found. Review only; no edits, tests, builds, GUI or remote operations performed.

### Final result

No actionable Spec findings in `13adedd..41eeccc`, with `8451227...41eeccc` inspected as needed.

Prior findings remain resolved:

- Audio rechecks cancellation after startup, and presentation context changes invalidate queued playback. [TapSound.swift:146](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/TapSound.swift:146>), [OverlayController.swift:657](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/OverlayController.swift:657>).
- Lock fallback preserves unrelated captured pairs and swallows owned Escape repeats through their matching release. [InputTap.swift:166](</Volumes/Project-Vault/PROJECTS/Please Look Here/Sources/TinyHand/InputTap.swift:166>).

No remaining material requirement gaps, incorrect behavior, or unselected feature scope found.

Read-only source and test review. No edits, tests, builds, GUI, nested agents, or remote actions performed.

The final Standards review includes the subsequent permission-fallback correction. That correction preserves the accepted scope and has its own failing-before/passing-after blocked-start regression. Full validation records are in VALIDATION.md. A separately reproduced preexisting own-window Point release issue was also fixed and tested.

Standards: five initial findings across rounds, zero open, highest severity P2. Spec: two initial findings, zero open, highest severity P2.

