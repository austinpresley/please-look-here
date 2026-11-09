# Local control protocol

The bundled executable accepts one JSON request after `--ctl`. It talks to the running
app through a same-user Unix socket. It never simulates shortcuts, launches another
overlay, or automatically replays a mutation.

Use `--help` for operations and `--version` for the app version. Review builds use
bundle ID `com.austinpresley.pleaselookhere.integration`; the upstream build identity
remains configurable. Check `TinyHandControlVersion = 1` in Info.plist before invoking
a client against an unfamiliar build.

```sh
APP="/absolute/path/TinyHand Integration.app"
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"status"}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"mode","mode":"point"}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"on"}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"configure","settings":{"motion":"responsive","lineWidth":8,"opacity":0.7}}'
```

## Requests

All requests have numeric `version: 1` and a string `operation`. Unknown fields,
operations, enum values and invalid numeric/boolean values are rejected.

| Operation | Other fields | Behavior |
| --- | --- | --- |
| status | None | Native state, permissions, settings and available operations |
| styles | None | Pointer IDs, names, types and optional local thumbnails |
| on / off | None | Idempotent activation / deactivation |
| toggle | None | Toggle once |
| mode | mode: point or draw | Choose the interaction mode |
| tool | tool: pen, rectangle, arrow, text or number | Select Draw and its tool |
| clear / undo / redo | None | Use the same annotation history as the toolbar |
| capture | None | Start a screenshot asynchronously |
| style | style ID; optional activate boolean | Select a pointer, optionally activate |
| laser | None | Activate and select the laser |
| configure | settings object | Validate every field before writing a batch |
| toggle-sound | None | Toggle hand sound |
| pin | style ID; pinned boolean | Keep between one and eight toolbar pins |
| settings | optional section string | Open General, Shortcuts, Drawing, Pointers, Appearance, Sound or About by lowercase name |
| custom-hands | None | Open the existing hand creator |

Point works without Accessibility. Draw needs Accessibility. Capture needs Screen
Recording and uses the same permission/error UI as the camera button. Client
processes do not need drawing permission just to send requests.

Capture acceptance is not capture completion. After `capture` succeeds, read status
until `capturing` is false, then inspect `lastCaptureError`, `lastCapture` and
`captureSize`. Clipboard-only captures have no saved path.

## Validated settings

- style: an available pointer ID; discover IDs with styles.
- ink: match, red, orange, yellow, green, blue, purple, white or black.
- fade: 0, 3, 6 or 10 seconds.
- size: 0.04 through 0.20.
- lineWidth: 2 through 20 points.
- opacity: 0.1 through 1.
- smoothing: integer 0 through 3, meaning Off, Very light, Light and Medium.
- motion: original or responsive.
- theme: system, light or dark.
- shadow, handSound, laserSound, showToolbar, captureCopies, captureSaves: booleans.
- tapSound: thock, click, pop, wood, boop or squeak.
- captureFolder: absolute directory path. A file path is rejected.

At least one capture output must remain enabled. Omitted values remain unchanged.
Validation finishes before writing anything. A valid batch publishes one native
preferences notification. This is not a crash-durable database transaction.

## Responses and errors

A response is one JSON object with version, ok and acknowledged state. State includes
active mode/tool, annotation count and undo availability, motion method and clock,
permissions, capture progress, settings, pins, and visible app window IDs.

Native errors return ok=false and an error with code and message, plus current state.
Exit 0 means acknowledged, 1 means native rejection, and 2 means transport/usage
failure. A timeout leaves the result uncertain. Refresh status before deciding what
to do; do not replay toggle, clear or another mutation blindly.

The app must already be running. A launcher may open the app, then use a bounded
status readiness check. Never spawn another copy merely because a request timed out.

## Transport

The app's per-user temporary directory has mode 0700; its socket has mode 0600.
Both peers check same-user identity. An exclusive lock prevents competing servers.
Requests are bounded to 16 KiB, responses to 2 MiB, with short I/O deadlines.
There is no network listener or arbitrary shell command operation.

## Local verification

Run `bash scripts/run-tests.sh`. Tests use an isolated preferences suite and
temporary hand directory. PNG clipboard tests use a private pasteboard.

A test instance started with TINYHAND_TEST_MODE=1 additionally exposes
snapshot-settings with an absolute PNG path. It captures only a focused, visible
Settings window and writes layout probes alongside it. Start with APP_SNAPSHOT set
to the verification directory. After focusing Settings, run
`python3 scripts/snapshot-settings.py`. This operation is absent from normal
app capabilities. All verification and packaging run locally; hosted CI stays disabled.
