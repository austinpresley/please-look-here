# Stream Deck plugin

The plugin controls the app through its private [local control socket](control-protocol.md).
Install it from **Look Here Please Settings → General → Install Stream Deck Plugin…**.
The signed app contains its matching signed/notarized installer. Stream Deck owns
the confirmation. Finish there, then add actions to keys yourself. The Settings
handoff message does not claim installation succeeded. Existing profiles and key
assignments are preserved. The app must be running to control it; a key never
launches it.

Requires Stream Deck 6.5 or later. If it is missing, Settings links to
[Elgato's official downloads](https://www.elgato.com/us/en/s/downloads), verified on
10 November 2026. A missing or corrupt installer asks you to reinstall Look Here
Please. If opening fails, open Stream Deck and try the Settings action again.
There is no runtime download or remote plugin updater.

## Actions

| Action | Press | Key shows |
| --- | --- | --- |
| Pointer On/Off | Toggle the pointer currently selected in the app, preserving that selection | The selected hand or laser, with On or Off |
| Interact | Change Interact | Interact On or Interact Off |
| Choose Pointer | Advance through every enabled, available pointer and wrap; preserve On/Off and Interact | Current acknowledged hand or laser, with On or Off |
| Select Pointer | Select the configured pointer and, by default, turn it on | The pointer, with a check when it is selected |
| Choose Tool | Cycle tools or select the fixed tool set in this key's inspector; turn Interact off and preserve pointer On/Off | Cycle: actual acknowledged tool. Fixed: assigned tool. Observed On/Off and Interact/Draw; fixed ready check requires a matching actual tool |

Pointer On/Off always uses **Current pointer**. Its read-only inspector explains
this behavior. Choose your hand or Laser dot in Look Here Please, then press the
key to turn it on or off. There is no fixed-pointer override on the toggle.
Existing toggle keys keep their action ID and need no settings migration. Any
saved `style` or `activate` fields on those keys remain ignored. Select Pointer
keeps its separate fixed-selection behavior and app-side eligibility validation.

## Choose Pointer and saved fixed keys

Add **Choose Pointer** for the normal cycle action. Its read-only inspector has
no fixed-pointer picker and writes no settings. The app advances in library order:
built-in hands, custom manifest order, then Laser dot. All enabled, available
choices participate, including unpinned and custom pointers. One choice stays
selected. A current pointer outside the set selects the first usable choice.
Disabled/missing choices are skipped, and edits apply on the next app request.
Cycling keeps On/Off and Interact unchanged. Use Pointer On/Off to activate it.

Choose Pointer has new UUID `com.austinpresley.lookhereplease.choose-pointer`.
Select Pointer keeps UUID `com.austinpresley.lookhereplease.select-pointer` and
its saved `style`/`activate` settings. It still chooses one fixed pointer. No saved
fixed ID becomes a list or cycle mode. There is no migration. The toggle UUID and
style-free `toggle` request are unchanged. Plugin version is 1.0.3.2. The original pointing-glove icon identifies the plugin and category; action/key feedback is unchanged.

## What a key means

Key state comes from the app. The plugin reads status every half second while keys
are visible, so changes from the app or another client appear on their own.
Hand artwork comes from the app's cropped thumbnails, including custom hands.
The plugin safely refreshes the catalog every two seconds while pointer keys are
visible, with backoff after failed reads. Replacing a custom image with the same
ID updates the key without a reconnect. An unavailable thumbnail shows an amber
image/question symbol with the observed On/Off value; it does not substitute a
different hand. App-owned selection repair after disabling or removing the
selected hand appears on the key through the next status read.

| Appearance | Meaning |
| --- | --- |
| White inner border | The key is physically down |
| Amber arc, top left | A command is outstanding. The previous state stays visible |
| Green arrow, top left | The app accepted the command |
| Red octagon and red text | The app rejected the command, with the reason |
| Amber question mark, "Check app" | No reply arrived, so the result is unknown. The command is not repeated |
| Lavender border and check | The observed state is on or selected |
| Amber lock | Accessibility is missing, so Interact cannot be turned off |
| Amber circular arrow | A read failed. The last known state is shown while the plugin retries |
| Grey power symbol, "Not running" | The app is not running |
| Amber triangle, "No reply" | The app is not answering |

The plugin retries only safe status and catalog reads. It never repeats a sent
mutation on its own. Pointer On/Off, Interact and Select Pointer keep their
existing pending suppression: another press while pending queues no mutation.

Choose Pointer treats the first keyDown as one intent and requires keyUp before
another. Holding a key or duplicate keyDown events never repeats it. Rapid complete
keyDown/keyUp presses join one FIFO shared by pointer-cycle and tool keys, with one selection
request outstanding at a time. The app resolves each next pointer when it runs;
the plugin never computes the next style from cached status or thumbnails.

After an uncertain result, the sent intent is never retried. Unsent intents wait
for a later successful status read before continuing. Read failures keep them
paused. A stopped app cancels unsent intents; leaving a key's page cancels its
unsent intents. An already-sent request can still finish. The queue is never saved
across plugin exit. A rejection is acknowledged, shown as an error, and subsequent
unsent intents can proceed. These rules preserve rapid presses without treating
recovery as permission to repeat an uncertain mutation.

## Local verification

`scripts/deck-replay.py` requires a running disposable test instance, a matching
`--suite` and a disposable `--hands` directory. It checks the running process's
suite before any mutation and reuses that same suite and directory on restart.
Add `--current-pointer` with the documented `custom-s019` and missing-image fixture
to check selected-pointer artwork, asset replacement/fallback and real socket
fault handling. That mode compares received key images with observed-state
fixtures rendered by the plugin's `--render-key <fixture.json> --output <png>`
helper. See [VALIDATION.md](VALIDATION.md) for the commands, fixture schema and
S-019 evidence. Replay does not establish physical Stream Deck acceptance.

The read-only inspector registers using Elgato's documented
[property inspector WebSocket callback](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/).
It sends no settings writes or app commands.


For S-020, run `python3 scripts/deck-cycle-replay.py --app <app> --plugin <binary>
--suite <disposable-suite> --hands <disposable-directory> --out <evidence-folder>`.
Use `custom-s019` with a PNG and `custom-s019-missing` without one in the disposable
manifest. The runner checks the running suite before mutation, compares received
key frames against the real fixture renderer, and forwards all cycle requests to
the installed app. Delayed/dropped replies, rapid complete presses, held duplicates,
multiple keys, catalog changes, uncertainty and page cancellation have dedicated
checks. Keep the S-019 `--current-pointer` replay as a separate regression gate.

The event boundaries follow Elgato's [keyDown/keyUp and willDisappear reference](https://docs.elgato.com/streamdeck/sdk/references/websocket/plugin/).
Only Keypad is registered; dial support is not claimed. Inspector registration
uses the [official UI callback](https://docs.elgato.com/streamdeck/sdk/references/websocket/ui/).
Host rendering and a physical press remain separate acceptance checks.

## Choose Tool

Add **Choose Tool** and use its native **Tool choice** inspector field. The default
is **Cycle tools**. A fixed Pen, Rectangle, Arrow, Text or Number choice applies
to this key only. The app owns the cycle in that order, wrapping Number to Pen.
Selection turns Interact off like the toolbar and preserves the selected pointer
and its On/Off value. If the pointer is off, use Pointer On/Off to turn it on.
Accessibility is required. A screenshot in progress rejects the change until it
finishes. Both failures leave tool, activation and Interact unchanged.

Cycle keys show the tool actually selected in the app. Fixed keys always show
their assigned tool symbol/name, so Pen, Rectangle, Arrow, Text and Number keys
stay distinguishable when another tool is selected. `On · Draw`, `Off · Draw`,
`On · Interact` or `Off · Interact` report the app's independent observed states.
A fixed key gets a lavender ready check/border only when its assigned tool matches
the acknowledged current tool, with pointer On, Interact off, Accessibility and
no capture. Cycle readiness uses those same drawing conditions for the current
tool. A lock means missing Accessibility;
an hourglass means capture in progress. Pending retains the prior observation.
The press border, pending arc, accepted receipt, rejection, uncertainty and stale
marks retain the meanings above. A stale mark replaces the readiness check and
never claims a fresh sample. A stale fixed key also loses its active border. Fixed names stay visible through errors, uncertainty and connection failures; guidance uses the detail line. Missing tool/capture state shows Tool unknown, with the fixed destination still visible.

The action has UUID `com.austinpresley.lookhereplease.choose-tool`. It saves
`tool:"cycle"`, `"pen"`, `"rectangle"`, `"arrow"`, `"text"` or `"number"`.
An absent field defaults to cycle; unknown/malformed saved values stay invalid,
show inspector guidance and reject with Choose Tool. Opening the inspector never
writes a default or silently repairs a saved choice. Explicit changes preserve
unrelated saved fields. External `didReceiveSettings` updates the native field
without writing it back.

Rapid complete presses queue once each for both cycle and fixed choices. Each
queued command keeps the choice that existed at its press, even if settings later
change. Tool and pointer cycles share one FIFO. Only safe reads retry; uncertain
sent selections never retry. Disappearing keys and stopped app cancel unsent work.
No key/profile is migrated and no queue persists across plugin exit.

Run `python3 scripts/deck-tool-replay.py --app <app> --plugin <binary> --suite
<disposable-suite> --hands <disposable-directory> --out <evidence-folder>` against
an isolated LaunchServices test process. It requires the same disposable fixtures
as S-019/S-020 and checks the running suite before mutation. The original S-021 baseline passed 120/120 real plugin/app checks. After the fixed-key review correction, fresh checks passed 168/168, including simultaneous fixed keys, external changes and pending selection. Fresh pointer regressions retained 87/87 pointer-cycle and 66/66 current-pointer checks. Received 72/144 px sheets and narrow inspector layouts were inspected.
Exact commands, evidence and remaining accessibility/hardware limits are in
[VALIDATION.md](VALIDATION.md). Capture rejection is unit-tested with a canceled
capture before any image/clipboard/file work; the capture artwork sample is a
fixture. A test-only denied grant exercises real app rejection without revoking
Austin's actual macOS grant. No physical key, host inspector or dial is claimed.


## Local packaging contract, S-022

`build-app.sh` forwards to `build-review.sh`; `release.sh` forwards with
`--package-only`. Both use the same local pipeline. `build-review.sh` invokes
`build-streamdeck.sh` once before app assembly/signing. The plugin script is a
leaf: it builds only LookHerePleaseDeck and never invokes an app wrapper or
`make_bundle`. There is no recursive build edge.

The plugin lane builds universal arm64/x86_64, signs with timestamped hardened
Developer ID team G2R8798RLT, validates with Elgato CLI 1.10.0, archives with
executable mode intact and requires its own Accepted notarization. The extracted
archive must match the built manifest and every payload file, pass strict
signature/universal/Elgato validation and retain the executable bit.

`scripts/streamdeck-package.py record` records plugin UUID/version, required host
version, exact installer SHA-256, notarization ID and hashes of all plugin inputs.
`make_bundle` requires this fresh record and copies the exact installer into
`Contents/Resources` with `StreamDeckInstaller.json`, which additionally binds
app version/build. Missing/stale/changed inputs fail packaging. The app signature
seals both resources. Runtime validates the receipt's identity/app version/build
and archive hash before passing that resource to the actual host with NSWorkspace.
No checkout or dist path is consulted by the installed app.

The app has its own Accepted notarization, stapling and Gatekeeper lane. Final
ZIP extraction validates the receipt and nested installer again, including its
signature, manifest, universal payload, executable mode and Elgato validation.
Run `bash scripts/run-tests.sh` for isolated app tests, package failure tests and
four layout lints. A standalone developer plugin build is still available with
`bash scripts/build-streamdeck.sh`; users install from Settings.

On this Mac, the Settings action opened host 7.6.0's real installation confirmation.
The host reported installation and its Plugins page showed Look Here Please by
Austin Presley, version 1.0.3.1. The installed payload matched every packaged byte
and the plugin connected to the host. All original profiles/keys were unchanged.
The intentional installation remains. See S-022 in VALIDATION.md for evidence.
MCP Deck is the only available canvas, and its Profiles page exposes no disposable
profile editor. No existing key was reassigned to inspect property inspectors.
Host inspector keyboard/VoiceOver and S-020/S-021 physical key checks remain open.
