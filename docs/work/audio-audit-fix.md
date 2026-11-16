# S-049 audio queue audit correction

Implemented 15 November 2026 on `t3/fix-audio-mute-queue-race`, starting at
`e8a03cd`, in `/Users/apresley/.t3/worktrees/Please Look Here/t3-1dad2538`.

## Failure and correction

The round 2 P2 was reproducible with the real `TapSound` queue and an injected
driver. The driver records a scheduled, unfinished buffer and blocks inside
`play`. While that serial queue is held, the caller queues another press, mutes
or sets volume to zero, attempts playback while silent, restores positive output,
and changes volume again. Only then does the driver release the queue.

Before the correction, both parameter cases failed. One buffer remained
scheduled, no stop occurred, and the next fresh tap reused the old driver.
The test produced 10 assertion failures across the two cases. Ticket cancellation
already prevented pending presses from playing, but could not discard a buffer
the driver had already scheduled.

`TapSound.setOutput` now captures whether each changed configuration is
inaudible. That queued operation must tear down the driver even when a later
configuration has restored positive output. Gain updates continue reading the
latest gate gain, so delayed positive updates cannot restore a stale volume.
`SoundOutput.swift` needed no change.

## Ordering guarantees and adjacent cases

- The gate still invalidates playback tickets synchronously on every changed
  output configuration. Restoring positive output does not revive old tickets,
  including startup blocked before the driver's `play` call.
- A mute or zero-volume request retains its teardown in serial queue order.
  Restoring output alone does not start a driver or replay a buffer.
- A fresh tap after restoration creates a replacement driver and uses the latest
  gain. Positive-only volume changes update the live driver without canceling
  its scheduled buffer or rebuilding it.
- Teardown still advances the driver's generation. A delayed configuration
  notification from the discarded driver cannot stop its replacement. The
  existing render-watchdog generation check remains unchanged.
- Driver start, gain, playback and stop remain on the existing serial audio queue.
  The tests assert that none of those calls runs on the main thread.

## Local verification

Run on Austin's Mac, macOS 27.0, Apple Swift 6.4. The package remains in its
existing Swift 5 language mode with the unchanged macOS 13 deployment target.
No UI automation, real-device playback, install, signing, packaging or hosted CI
was run.

All invocations used these isolated paths and preference suite:

```sh
export TINYHAND_DEFAULTS_SUITE=com.austinpresley.tinyhand.unit.audio-audit.t3-1dad2538
export TH_HANDS_DIR=/tmp/lookhere-audio-audit-t3-1dad2538/Hands
export TH_THUMBNAILS_DIR=/tmp/lookhere-audio-audit-t3-1dad2538/Thumbnails
mkdir -p "$TH_HANDS_DIR" "$TH_THUMBNAILS_DIR"
```

Failing before correction, exit 1, two cases and 10 assertion failures:

```sh
swift test --filter 'SoundOutputTests/inaudibleTransitionCancelsScheduledAudioEvenWhenOutputIsRestoredBeforeQueueDrains'
```

Passing after correction, 13 sound-output tests, including both scheduled-buffer
cases, positive-only rapid changes, blocked startup with and without output
restoration, preview cancellation and preference/choice preservation:

```sh
swift test --filter SoundOutputTests
```

Final verification after adding the discarded-driver notification assertion,
20 tests in two suites passed. The seven selected `AudioTests` use fake drivers
or read the source WAV files. The two overlay/presentation tests were excluded
because their app/UI setup belongs to the parent's integrated validation.

```sh
swift test --filter '(SoundOutputTests|AudioTests/(everySoundHasADecodablePackagedSourceFile|blockedAudioDeviceNeverBlocksTheCaller|configurationChangesRebuildInsteadOfResumingTheOldEngine|missingRenderDiscardsTheBrokenDriver|mutingDoesNotStartAnEngine|aQueuedTapIsCancelledWhileTheDeviceIsBlocked|mutingDuringTheFirstPlaybackStartupPreventsThatPlayback))'
git diff --check
```

Builds completed locally with no warnings or errors in these test logs. Evidence
logs are `/tmp/lookhere-audio-audit-t3-1dad2538/red.log`, `green.log` and `audio.log`.
No normal preferences, user Hands, shortcut assignments, Stream Deck profiles,
bundle identity, deployment settings or central project documents were changed.
There are no glossary or product-copy proposals for this correction.

## Parent acceptance remaining

Integrated UI and real-device audio acceptance remain with the parent. Verify
live tap audio and sound previews during rapid mute/unmute and zero/positive
volume changes. Current and queued sound must stop and never replay on restore;
a later fresh tap must use the final volume. Exercise device/route recovery and
the integrated presentation cancellation paths. The injected-driver tests prove
queue ordering and cancellation identity, not physical AVAudioEngine output or
device latency. The parent also owns integrated build and packaging acceptance.
