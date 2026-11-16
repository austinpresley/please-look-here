# Final native input checks

Completed locally on Austin's Mac on 16 November 2026 at 02:39 EST. No hosted CI, nested agents, source changes, signing, packaging, installation, commits, host plugin changes or deliveries were performed.

## Identity and isolation

Tested exactly `/Volumes/Project-Vault/PROJECTS/Please Look Here/dist/Look Here Please.app`, version `1.2.0`, build `20261116015628`, control protocol 1. Executable SHA-256 before and after was `e54075242a0b47022bdb988e9b955c8b888dfea09c5d41dc8cb324dfaccd4754`. Strict deep codesign verification passed. Gatekeeper accepted the app with `source=Notarized Developer ID`.

- Defaults domain: `com.austinpresley.tinyhand.s013.a4a78cd8-5d7c-4c66-927a-19c01c7537a0`.
- Temporary root: `/var/folders/8h/r0gxs7ls4kgc804g7lj475q80000gn/T/s013-native-final-9364xp58`.
- `TH_HANDS_DIR`: that root's `hands` directory.
- `TH_THUMBNAILS_DIR`: that root's `thumbnails` directory.
- `TINYHAND_TEST_MODE=1`.
- Output and `APP_SNAPSHOT`: `/Volumes/Project-Vault/PROJECTS/Please Look Here/dist/verification/app-review-20261115/native-final`.
- Existing fixture: `/Volumes/Project-Vault/PROJECTS/Please Look Here/dist/verification/app-review-20261115/TinyHandFixture.app`.
- Fixture state: `/tmp/s013-native-final-a4a78cd8-5d7c-4c66-927a-19c01c7537a0.json`.

Both instances were launched with normal LaunchServices `open -n --env` arguments recorded in `environment.json` and `fixture-environment.json`. The initial app state had no visible app windows. The native probes were compiled from the existing project fixtures into this output directory with `swiftc -target arm64-apple-macos13.0`. The default macOS 27 SDK target initially rejected the older screenshot API in RadialProbe; using the project's existing macOS 13 deployment target compiled the unmodified source. The probe's broad `shot` operation was never used. Image capture used only `test-radial` on the app's own radial window.

The installed `~/Applications/Look Here Please.app` was not launched, replaced or modified. The parent owns its final identity and normal preference/profile preservation comparison.

## Results

`checks.json` records 13 passing behavioral checks and zero failing behavioral checks. `openings.json` retains all 26 successful native opening observations, including the 20 consecutive fresh gestures. Every opening compares app state against the matching actual WindowServer window ID and alpha greater than 0.01.

1. Real Carbon conflict isolation passed. While pointer was Off, assigned capture to Ctrl+Option+J, mode to Ctrl+Option+K and exitPointer to Ctrl+Option+L through `test-shortcuts`. All three contextual registrations were inactive. A locally compiled ShortcutBlocker then exclusively registered capture's combination. Activating the pointer reported exactly the capture conflict and retained two registrations. Guarded bundled `InputProbe key mode` changed Interact from On to Off, and `InputProbe key exitPointer` deactivated the pointer. The capture combination itself was never posted. Evidence: `carbon-conflict.json`.
2. Real conflicting replacement rollback passed. After releasing the capture blocker, all three commands registered. A new blocker owned unused Ctrl+Option+semicolon. Replacing mode with that combination was rejected as unavailable. Every saved assignment stayed exactly equal to the previous assignments, three registrations remained, and the previous mode and exitPointer shortcuts still executed. Evidence: `carbon-replacement.json`.
3. Isolated radial setup passed with Option explicitly assigned, pointer active, Interact On, toolbar hidden, hand/laser sounds disabled and master sound muted.
4. An Option-modified click approximately 80 ms after modifier down reached the public fixture with one ordinary mouse down and one mouse up, both retaining Option. It canceled the pending radial and no panel was visible after the hold interval. Evidence: `radial-early-click.json`.
5. Space already down before Option blocked radial opening. Its ordinary down and up both reached the fixture. Evidence: `radial-space-before.json`.
6. Space held before enabling the radial tap also blocked opening through native key-state sampling. Evidence: `radial-space-before-tap.json`.
7. Twenty consecutive fresh Option hold/release gestures passed. Each began with eligible input, no held modifiers/buttons, no pending session and no visible radial. Exactly one flags callback opened each menu; both radial input state and the actual WindowServer window confirmed it. Each release closed it and cleared held ownership before the next press. There were no reposts, recovery waits or retries in this series. Completed holds waited approximately 210 ms before readback. Evidence: `openings.json`, labels `rapid-1` through `rapid-20`.
8. An ordinary modified key down, autorepeat and up canceled the menu and reached the fixture with the expected two downs and one up, preserving Option. Evidence: `ordinary-key-cancel.json`.
9. Owned Escape down, three repeats and up remained swallowed through menu closure. No Escape event reached the fixture, and owned keys drained. Evidence: `escape-closure.json`.
10. The same Escape ownership check passed through pointer deactivation; the tap disabled after ownership drained. Evidence: `escape-deactivation.json`.
11. The same Escape ownership check passed through trigger clearing; the tap disabled after ownership drained. Evidence: `escape-clear-trigger.json`.
12. Actual own radial window capture passed in light appearance. Evidence: `radial-light.png`, `radial-light-layout.json`, `snapshot-light.json`.
13. Actual own radial window capture passed in dark appearance. Evidence: `radial-dark.png`, `radial-dark-layout.json`, `snapshot-dark.json`.

The light and dark images were inspected. They show the radial controls, selected Interact On state and readable footer without capturing desktop content.

## Preserved prerequisite failure

The first harness run stopped at frontmost guards because macOS reported Terminal as frontmost, despite the public fixture being visible and CUA window Raise/click actions. No guarded native probe input was emitted in that run. Its checks and failed opening prerequisites remain in `focus-prerequisite-failure/`; these are not counted as behavioral passes. LaunchServices `open -a` on the exact already-running fixture established genuine fixture focus, then the complete suite ran. This was a focus prerequisite correction, not a retry of a posted hold. No failed posted radial transition was reclassified as success.

## Cleanup

Before quitting, released the possible posted keys/buttons over the frontmost fixture, turned the pointer Off, returned Interact On, cleared only the three disposable shortcuts and disposable radial trigger, and confirmed no active input tap, no visible radial, no held modifier/button and zero Carbon registrations. Both blocker processes terminated. Evidence: `pre-ui-quit-cleanup.json`.

Quit the isolated app through CUA's own application menu, Quit Look Here Please. Its subsequent state read returned `procNotFound -600`, consistent with termination. Quit the fixture through its own Quit Test Canvas menu. A final process inventory found no TinyHand app, fixture, ShortcutBlocker or RadialProbe running, so no test canvas remains visible and the parent can install. Evidence: `final-cleanup.json`.

CUA selecting the already-running app by its exact path reopened Settings during cleanup. No Settings control or plugin installer was activated; the app was immediately quit through its own menu. The disposable defaults domain and temporary data directories were retained for evidence. Normal preferences and Hands were not intentionally read or written by the test harness.

## Limits

These checks used guarded native CGEvent input over the public fixture, not a physical keyboard or mouse. They demonstrate an early click before the 180 ms deadline and a completed hold after it, without claiming millisecond-exact native scheduling or a physical 179/180 ms boundary measurement. Only Option was exercised in this final run. Physical missed releases, hardware/display reconfiguration and intentionally delayed main-queue scheduling remain unverified here.

The historical intermittent reopen cause remains unestablished, even though all 20 fresh openings passed. Installation, source backup, final normal preference/Hands and Stream Deck profile comparison, physical Stream Deck checks and delivery remain the parent's work.
