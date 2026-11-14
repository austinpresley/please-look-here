# Local control protocol

The bundled executable accepts one JSON request after `--ctl`. It talks to the running
app through a same-user Unix socket. It never simulates shortcuts, launches another
overlay, or automatically replays a mutation.

Use `--help` for operations and `--version` for the app version. Review builds use
bundle ID `com.austinpresley.pleaselookhere.integration`; the display name is Look Here Please. Check `TinyHandControlVersion = 1` in Info.plist before invoking
a client against an unfamiliar build.

```sh
APP="/absolute/path/Look Here Please.app"
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"status"}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"interact","enabled":true}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"on"}'
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"configure","settings":{"motion":"responsive","lineWidth":8,"opacity":0.7}}'
```

## Requests

All requests have numeric `version: 1` and a string `operation`. Unknown fields,
operations, enum values and invalid numeric/boolean values are rejected.

| Operation | Other fields | Behavior |
| --- | --- | --- |
| status | None | Native state, permissions, settings and available operations |
| styles | None | Complete pointer library, including disabled and unavailable entries; IDs, names, types, eligibility metadata and optional local thumbnails |
| enable-pointer | style ID; enabled boolean | Save eligibility independently of toolbar pins; disabling current selects the first remaining enabled available pointer |
| on / off | None | Idempotent activation / deactivation |
| toggle | None | Toggle activation of the currently selected pointer once, without changing selection |
| interact | enabled: boolean | On uses apps normally; off captures annotations |
| mode | mode: point or draw | Legacy v1 alias: point means Interact on, draw means off |
| tool | tool: pen, rectangle, arrow, text or number | Turn Interact off and select its drawing tool |
| cycle-tool | None | Select the next drawing tool and wrap; turn Interact off and preserve pointer activation/selection |
| clear / undo / redo | None | Use the same annotation history as the toolbar |
| capture | None | Start a screenshot asynchronously |
| magnifier | enabled boolean | Start or stop live magnification independently of the selected pointer; Screen Recording is required |
| gesture | slot: first, second or none | Show a hand pose for two seconds, or cancel it; invalid/unavailable non-hand targets reject before activation |
| style | style ID; optional activate boolean | Select a pointer, optionally activate |
| cycle-pointer | None | Advance once through all enabled, available pointers and wrap; preserve activation and Interact |
| laser | None | Activate and select the laser |
| configure | settings object | Validate every field before writing a batch |
| toggle-sound | None | Toggle hand sound |
| pin | style ID; pinned boolean | Keep between one and eight toolbar pins |
| settings | optional section string | Open General, Shortcuts, Drawing, Pointers, Appearance, Sound or About by lowercase name |
| custom-hands | None | Open the existing hand creator |

Interact works without Accessibility. Turning it off to draw needs Accessibility. Capture needs Screen
Recording and uses the same permission/error UI as the camera button. Client
processes do not need drawing permission just to send requests.

Capture acceptance is not capture completion. After `capture` succeeds, read status
until `capturing` is false, then inspect `lastCaptureError`, `lastCapture` and
`captureSize`. Clipboard-only captures have no saved path.

## Validated settings

- style: an enabled, available pointer ID; discover IDs and eligibility with styles.
- ink: match, red, orange, yellow, green, blue, purple, white or black.
- fade: 0, 3, 6 or 10 seconds. Chooses legacy permanent/whole-line fading unless the batch supplies inkFadeStyle.
- inkFadeStyle: wholeLine, trail or permanent. Trail animates pen visibility while keeping complete annotation history.
- trailDelay: 0.2 through 3 seconds; trailSpeed: 40 through 600 points per second.
- magnifierZoom: 1.5 through 6; magnifierDiameter: 160 through 480 points.
- tapSwing: 0 through 2. Zero preserves the existing tap; Reduce Motion suppresses swing.
- size: 0.04 through 0.20.
- lineWidth: 2 through 20 points.
- opacity: 0.1 through 1.
- smoothing: integer 0 through 3, meaning Off, Very light, Light and Medium.
- motion: original or responsive.
- theme: system, light or dark.
- shadow, handSound, laserSound, showToolbar, interactKeepsHand, captureCopies, captureSaves: booleans.
- shadowStyle: `original` or `contact`. The separate `shadow` boolean controls visibility without losing this choice.
- tapSound: thock, click, tock, clack, typewriter, snap, wood, pop, boop, blip, coin, pew, squeak, quack or chirp.
- captureFolder: absolute directory path. A file path is rejected.

At least one capture output must remain enabled. Omitted values remain unchanged.
Validation finishes before writing anything. A valid batch publishes one native
preferences notification. This is not a crash-durable database transaction.

## Responses and errors

A response is one JSON object with version, ok and acknowledged state. State includes
active mode/tool, the Interact boolean, pointerVisible, annotation count and undo availability, motion method and clock,
permissions, capture progress, settings, pins, and visible app window IDs.
It also reports magnifying, magnifier lifecycle/frame diagnostics, current gesture slot,
contactSoundPending and onActiveSpace. Magnification is off after pointer shutdown;
gesture slots do not become pointer IDs or change pointer cycling. Gesture hold
shortcuts are `gesture1` and `gesture2`; `magnifier` is the optional toggle shortcut.
All three begin Unassigned, including after Reset All.
`shortcuts` maps each command ID to either `null` for Unassigned or an object with
`keyCode`, Carbon `modifiers` and `display`. Fresh preferences have all values null.
Use Settings → Shortcuts to assign or clear commands. `configure` does not accept
shortcut assignments, and omitted configuration values never install presets.
Automation actions such as `undo` work directly without a keyboard assignment.

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
`python3 scripts/snapshot-settings.py`. A test instance also exposes run-applescript
with a source string, which runs AppleScript inside the app so dictionary checks need
no Automation consent. Setting TINYHAND_TEST_DENY_ACCESSIBILITY=1 on a test instance
reports Accessibility as missing to control clients. These operations and settings are
absent from normal app capabilities. All verification and packaging run locally; hosted CI stays disabled.

### Isolated shortcut verification

`test-shortcuts` exists only with `TINYHAND_TEST_MODE=1`. Launch with a disposable
`TINYHAND_DEFAULTS_SUITE` and `TH_HANDS_DIR`. An empty `request` reads saved
assignments, current global registration count, menu equivalents and the last
assignment error. A request with `command` and `shortcut` calls the same validated
assignment path as Settings; a null shortcut clears it. `command: reset` invokes
the same preference reset used by Reset All. This operation is absent from normal
app capabilities. `scripts/shortcut-smoke.py` checks it before any mutation.

## Enabled pointer catalog, S-018

`styles` retains its v1 response shape and includes the entire library. Each
entry adds `enabled`, `available`, `selectable` and `pinned` booleans. A missing or
unreadable custom PNG has `available:false` independently of `enabled`. Its
manifest entry stays in Settings. Restoring the file restores availability,
keeps the saved enabled state and pins, and does not select it automatically.
Explicitly deleting a hand removes its manifest entry; selecting that ID returns
`unknown-style`. Disabled IDs remain saved, so restoring the same ID also restores
its disabled choice. Assets and customization are never deleted by disabling.

Every acknowledged `state` adds these arrays:

- `enabledPointers`: ALL enabled AND available IDs in built-in library order,
  followed by custom manifest order, then `laser`, `spotlight` and `presentation`. This is the shared
  source for Stream Deck cycling and future radial pointer choices. It includes
  unpinned choices. Use it directly; do not derive a cycle from `pinned`.
- `quickPointers`: enabled, available saved pins in pin order. If none are usable,
  it contains the first enabled available library entry as a temporary toolbar
  fallback, without changing saved pins. Existing next/previous pinned commands
  use this same filtered list and keep their existing clamped navigation.
- `disabledPointers`: explicitly disabled IDs, including IDs whose custom manifest
  entry has since been removed. `pinned` still reports saved toolbar favorites.

```json
{"version":1,"operation":"enable-pointer","style":"robot","enabled":false}
{"version":1,"operation":"styles"}
{"version":1,"operation":"style","style":"chrome","activate":true}
```

Built-in procedural choices have IDs `laser`, `spotlight` and `presentation`,
with matching `type` values. Hands retain `hand` or `custom`. Spotlight and
Presentation pointer are always available without image assets and export PNG
thumbnails like hands for Stream Deck and other clients. Select either through
`style`, cycle through enabled choices, or use AppleScript's selected pointer.

An entry can look like this, without a thumbnail when the image is missing:

```json
{"id":"custom-example","name":"My hand","type":"custom","enabled":true,"available":false,"selectable":false,"pinned":true}
```

Enable/disable and pin/unpin are independent. Pinning a disabled pointer is allowed
and does not enable it; enabling does not add a pin. Disabling preserves saved pin
order. All choices are enabled on an existing install, fresh preferences and
Reset All. New hand imports are enabled; the hand creator retains its existing
separate auto-pin behavior when the toolbar has room. Reset toolbar changes pins
only. No new hotkeys or Stream Deck actions are introduced by S-018.

`style`, `laser`, `configure.settings.style`, Settings Select and AppleScript
selection all validate before mutation. Known missing images return `missing-asset`
even if also disabled. Available disabled pointers return `disabled-style`, which
maps to AppleScript error 1006. `style` with `activate:true` and the legacy `laser`
operation reject before activation. A rejected configuration applies no fields.

Disabling the current pointer selects the first remaining enabled available entry
in library order and leaves activation and Interact unchanged. Disabling the last
one returns `last-enabled-pointer` with "Keep at least one available pointer
enabled." No preferences change on rejection. File/manifest changes are detected
within the one-second catalog refresh. If an external asset loss leaves no usable
enabled pointer, the app enables the first available library choice and selects
it, using Laser dot if no hand can load. This recovery is separate from a rejected
command. Invalid saved selections use the same deterministic fallback.

The in-process API is `PointerCatalog.entries`, `selectableStyles`, `quickStyles`,
`validateSelection(_:)`, `setEnabled(_:for:)` and `reconcile()`. Selection entry
points call validation; the overlay's `pick(_:)` returns false without mutation
on rejection. S-020 adds `nextSelectable(after:)` and the app-owned operation below,
using `selectableStyles` independently of toolbar pins.

For local verification, `scripts/pointer-smoke.py` requires an S-018 test suite
and disposable custom fixtures. It checks its matching suite before resetting
anything. Native launches still use LaunchServices and bounded readiness checks.

## Stream Deck current-pointer toggle, S-019

Pointer On/Off sends exactly `{"version":1,"operation":"toggle"}`. The app
resolves its current selection when the request runs. No plugin-side style
sample, saved fixed style or explicit on/off target is sent. The existing v1
operation already had this behavior; S-019 adds actual observed pointer artwork
and clear inspector copy rather than a new mutation or selection override.
`style`/`activate` are not accepted fields on `toggle`.

Keys poll status every half second and safely refresh `styles` every two seconds
while pointer keys remain visible. A rejected or uncertain mutation never advances
selection locally and is never replayed. Catalog reads export cropped hand images
inside the private control directory; the plugin loads those files rather than
reading Austin's hand library directly. The existing Select Pointer action still
uses validated `style`, including `disabled-style` and `missing-asset` rejections
before any activation. No protocol version, app operation or saved key schema
changes in S-019. S-020 cycling uses the separate operation below.


## Cycle enabled pointers, S-020

```sh
"$APP/Contents/MacOS/TinyHand" --ctl '{"version":1,"operation":"cycle-pointer"}'
```

The request accepts no other fields. On the app's main queue, refresh custom
manifest membership, read `overlay.style` and `PointerCatalog.selectableStyles`,
choose the next entry, validate and select it, then return acknowledged state.
ControlServer serializes requests and the complete operation cannot interleave
with Settings or another control mutation. The order is built-in library order,
custom manifest order, then Laser dot. It includes unpinned choices. It never uses
`quickStyles`, `pinnedStyles` or `state.quickPointers` as the cycle set.

One choice selects itself. A current pointer outside the set selects its first
entry. Disabled and unavailable entries are excluded. Each request recomputes the
set, so custom deletion/restoration and eligibility edits affect the next request.
Restoration itself does not steal selection. An empty usable set returns
`no-enabled-pointer`; a pointer whose image disappears during validation returns
`missing-asset`. Rejected requests change neither selection nor activation.
Normal catalog recovery still owns fallback after external loss.

Cycling preserves pointer activation and Interact, even while off. Use `toggle`
or `on` separately to activate it. `activate`, `style`, lists and other extra fields
are invalid on this operation. Existing `style` and pinned next/previous commands
keep their existing behavior. No protocol version change is needed.

The new Stream Deck Choose Pointer action queues deliberate press intents, not
locally computed styles. It sends the next request only after the previous reply.
A lost reply removes that sent intent permanently and pauses unsent intents until
a later successful status read. That safe read is serialized after the failed
request. Only never-sent intents then continue against current app state. The
uncertain mutation is never retried. A stopped app cancels unsent intents; a
hidden key cancels its own unsent intents. Queues are memory-only.

## Choose drawing tools, S-021

```json
{"version":1,"operation":"cycle-tool"}
{"version":1,"operation":"tool","tool":"rectangle"}
```

`cycle-tool` accepts no other fields. The app resolves `Preferences.drawingTool.next`
on the main queue in the stable toolbar order Pen, Rectangle, Arrow, Text, Number,
then Pen. Each request advances once against the current tool, including changes
from the toolbar or automation. The plugin sends no sampled current/next value.
The existing fixed `tool` operation accepts exactly `pen`, `rectangle`, `arrow`,
`text` or `number`. Unknown values and extra fields reject before mutation.

Both call the existing overlay `chooseTool` path after validating capture and
Accessibility. Success selects the tool and turns Interact off, preserving pointer
selection and On/Off. An off pointer stays off. Capture in progress rejects with
`capturing` and "Wait for the screenshot to finish before changing drawing tools".
Otherwise missing Accessibility rejects with `accessibility` and "Allow
Accessibility to use drawing tools". These rejections preserve tool, activation and
Interact. A failure to start drawing input returns `unavailable`. No operation
automatically activates the pointer or retries a mutation.

Acknowledged state already reports `tool`, `active`, `interact`, `accessibility`
and `capturing`; S-021 does not introduce a second app tool model. The plugin now
observes all five. A tool is ready only when the pointer is active, Interact is off,
Accessibility is allowed and capture is not pending. Missing/unknown tool or
capture state is unknown, never Pen or ready. Cycle keys identify the observed current tool. Fixed keys identify their configured destination, and only show the ready border/check when it matches the acknowledged current tool and drawing is ready. This review correction changes plugin presentation only; the protocol and queued command semantics are unchanged.

Choose Tool, UUID `com.austinpresley.lookhereplease.choose-tool`, stores a per-key
`tool` string: `cycle` or one of the five fixed IDs. Omission defaults to `cycle`.
Empty, null, non-string and unknown saved values are invalid; the inspector shows
guidance and the key rejects locally with "Choose Tool" without sending a command.
No saved pointer UUID or settings are reinterpreted.

All tool choices and Choose Pointer share `CycleQueue`. Each immutable-value
intent captures a typed `SelectionCommand` at keyDown, its context and incarnation.
Changing inspector settings affects future presses only. keyUp separates presses;
duplicate held keyDown adds nothing. FIFO, one outstanding selection request,
uncertainty pause/safe-read resume, permanent removal of uncertain sent commands,
page/stop cancellation and memory-only lifetime preserve S-020 rules. A replacement
key receives observations but never an old key's receipt or delayed transient
expiry. Pointer On/Off and legacy fixed-pointer pending suppression are unchanged.


## Settings plugin installer, S-022

`settings` with `section:"general"` opens the existing page containing Install
Stream Deck Plugin…. Installation is a local Settings action using the signed
app's matching bundled resource and Stream Deck's normal confirmation. It adds
no control operation, app mutation, plugin command, socket protocol version or
profile/key migration. The S-019/S-020/S-021 operations and FIFO rules above stay
unchanged. See [the package contract](streamdeck.md#local-packaging-contract-s-022).


## Radial quick controls

`configure` accepts `radialTrigger`, one of `""` for Unassigned, `"option"`,
`"control"`, `"shift"`, or `"command"`. Invalid values reject the whole batch.
This setting has no factory assignment. Clearing it preserves every explicitly
assigned presentation shortcut; Reset All clears all shortcut assignments as
before. The native Settings entry is Shortcuts > Quick controls at the cursor.

`toggle-current-sound` toggles the sound for the selected hand or laser through
the same overlay action as the toolbar. Legacy `toggle-sound` retains its original
hand-sound behavior. No Stream Deck protocol/schema changed.

State adds `settings.radialTrigger` and `radial`: actual panel visibility/window
number/frame, session center/arming/category/page/items, selected/highlighted
choices, release policy, Reduce Motion observation and last action result.
`input.radial` reports eligibility, held/open ownership and draining button/key
IDs; `input.capturedButtons` identifies annotation presses awaiting release.
Panel visibility derives from the actual native panel. Native smoke checks also
read Window Server independently and compare fixture-received input counters.

Only with `TINYHAND_TEST_MODE=1`, `test-radial` is discoverable. It additionally
requires `TINYHAND_DEFAULTS_SUITE` beginning `com.austinpresley.tinyhand.s013.`.
Its `request` accepts `releaseSelects` for the native policy comparison and
`snapshot` for an absolute PNG path of the actual visible radial window. Snapshots
also write measured `-layout.json`. It cannot inject production commands or bypass
pointer eligibility/permissions. Normal instances expose no test operation.

### S-023 menu bar verification

Menu bar controls use the existing validated operations. Pointer selection sends
`style` without activation; tools send `tool`; current hand/laser sound sends
`toggle-current-sound`. The legacy `toggle-sound` operation and Stream Deck
semantics are unchanged. `input.controls` adds read-only open/native-menu and
owned button/key diagnostics alongside existing tap diagnostics.

`test-menu-bar` additionally requires a `com.austinpresley.tinyhand.s023.` defaults
suite and accepts a `request` object. It observes the real control/menu state;
`open` opens/closes controls, `snapshot` writes a native own-window PNG plus optical
alignment probes, and `anchor` left/right with `width` 280/320 exercises edge and
narrow native layout without changing system displays. Normal app capabilities
omit this operation. `scripts/menu-bar-smoke.py` requires an exact-suite
LaunchServices instance, the guarded public fixture, MenuBarProbe and an isolated
environment.json. Failures retain state and fixture counters before cleanup.
