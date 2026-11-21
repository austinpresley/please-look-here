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
| tool | tool: pen, rectangle, arrow, text, number, eraser or highlighter | Turn Interact off and select its drawing tool |
| cycle-tool | None | Select the next drawing tool and wrap; turn Interact off and preserve pointer activation/selection |
| clear / undo / redo | None | Use the same annotation history as the toolbar |
| capture | None | Start a screenshot asynchronously |
| capture-region | None | Open a native drag selection; Escape cancels, release captures the selected region |
| magnifier | enabled boolean | Start or stop live magnification independently of the selected pointer; Screen Recording is required |
| gesture | slot: first, second or none | Show a hand pose for two seconds, or cancel it; invalid/unavailable non-hand targets reject before activation |
| style | style ID; optional activate boolean | Select a pointer, optionally activate |
| cycle-pointer | Optional `direction`: `forward` or `backward` | Cycle all enabled, available pointers and wrap; preserve activation and Interact |
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

Region capture first reports `selectingCaptureRegion: true`. A completed selection
starts the regular asynchronous capture path; cancellation takes no screenshot.
The result panel offers Reveal in Finder for saved files and Copy for the latest
image. Retry opens a new selection after a region error. The optional
`capture-region` shortcut starts unassigned.

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
- soundVolume: finite number from 0 through 1; soundMuted: boolean. Output mute does not change saved choices.
- pointerOverrides: dictionary of stable pointer ID to a field patch. Fields are size, shadow, shadowStyle, soundEnabled and sound. A null field restores inheritance; a null ID value restores that pointer's defaults. Validate the entire batch before writing.
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

`pointerConfiguration` and each style's `configuration` report effective values,
explicit overrides, applicability and archive health. `soundOutput` separates
pointer tap enablement from output gain/master mute. `annotations` is the current
visible count; full semantic history can still be available through Undo after
timed ink expires. New Eraser/Highlighter shortcuts start unassigned. The tool
cycle preserves the previous five tools' order, then Eraser, Highlighter and Pen.

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

The optional `direction` field accepts `forward` or `backward`. Omission keeps
forward behavior for existing protocol v1 clients and Stream Deck keys. Other
values or extra fields are rejected before mutation. For example:

```json
{"version":1,"operation":"cycle-pointer","direction":"backward"}
```

On the app's main queue, refresh custom manifest membership, read `overlay.style`
and `PointerCatalog.selectableStyles`, choose the next or previous entry with
wrapping, validate and select it, then return acknowledged state.
ControlServer serializes requests and the complete operation cannot interleave
with Settings or another control mutation. The order is built-in library order,
custom manifest order, then presentation pointers in catalog order. It includes unpinned choices. It never uses
`quickStyles`, `pinnedStyles` or `state.quickPointers` as the cycle set.

One choice selects itself. A current pointer outside the set selects its first
entry for forward, or its last entry for backward. Disabled and unavailable
entries are excluded. Each request recomputes the set, so custom deletion/restoration and eligibility edits affect the next request.
Restoration itself does not steal selection. An empty usable set returns
`no-enabled-pointer`; a pointer whose image disappears during validation returns
`missing-asset`. Rejected requests change neither selection nor activation.
Normal catalog recovery still owns fallback after external loss.

Cycling preserves pointer activation and Interact, even while off. Use `toggle`
or `on` separately to activate it. `activate`, `style`, lists and other extra fields
are invalid on this operation. Native Next Pointer and Previous Pointer use the
same full enabled/available catalog and wrap. Pins remain toolbar favorites.
Existing `style` requests keep their behavior. No protocol version change is needed.

The Stream Deck Choose Pointer inspector offers Forward and Backward. Opening it
never rewrites settings. A user direction change preserves all other saved keys;
legacy keys without a direction remain forward. Action UUIDs remain unchanged.
The action queues deliberate press intents with their direction captured at press
time, rather than locally computed styles. It sends the next request only after
the previous reply.
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

## Quick controls v9

`radial-open` opens persistent Quick controls at the real cursor through the
existing InputTap session owner. It has no extra fields. Pointer must be on,
Accessibility available, and other app controls closed. The action is also
available as **Open Quick controls** in the menu bar and Shortcuts settings;
its shortcut starts unassigned and uses the usual conflict rollback.

The existing `test-radial` operation accepts a `request` object in test mode
with a disposable defaults suite prefixed
`com.austinpresley.tinyhand.radial-v9.` or the legacy `s013.` prefix. It posts
no native input and changes no system accessibility preferences or grants.

```json
{"version":1,"operation":"test-radial","request":{"event":"open","mode":"persistent","point":[700,500],"bounds":[200,200,1000,700],"level":"color","highlighted":"match","keyboard":true,"appearance":"dark","opaque":true,"increaseContrast":false,"reduceMotion":true}}
```

Coordinates use AppKit screen points, origin at the lower left. `point` is a
finite `[x,y]`; optional `bounds` is a finite `[x,y,width,height]` owning usable
rectangle with both dimensions greater than 24. Omitting bounds uses the
invocation display. Either dimension below 384 selects the native scrolling
list. Never change the real display configuration for a snapshot.

Supported request fields:

- `event`: `open`, `state`, `move`, `press`, `release`, `cancel`, `key`, `close`.
  Default is `state`. `open` starts a fresh session, with `mode` equal to
  `held` or `persistent`. `move`, `press`, and persistent `release` require
  `point`. These call the session's native-event methods directly.
- `level`: `root`, `pointer`, `color`, `draw`, `more`. Child entry uses the
  session's keyboard navigation origin. `highlighted` is an exact item ID
  from diagnostics, including `back`. `keyboard` controls the focus outline
  on explicit inspection. It never makes an unavailable command executable.
- `key`: `tab`, `left`, `right`, `up`, `down`, `enter`, `space`, `escape`,
  `backspace`. Used with `event: key`. Normal modified native chords,
  including VoiceOver Control-Option chords, pass unchanged.
- `appearance`: `light` or `dark`. `opaque`, `increaseContrast`, and
  `reduceMotion` are boolean panel overrides. They never write system settings.
- `canUndo`, `canRedo`, `hasInk`: optional boolean catalog fixtures on open.
  They do not modify drawing history. `releaseSelects` retains the old
  comparison seam. Optional `sessionID` rejects a stale caller.
- `snapshot`: an absolute `.png` path. Capture in a separate `state` request
  after at least 120 ms to let opening and hub transitions settle. It captures
  only the owned Quick controls window and writes a sibling `-layout.json`
  with window coordinates, scale, exact visible content frames, sector axes,
  current/enabled flags, origin reserve and session diagnostics.

```json
{"version":1,"operation":"test-radial","request":{"event":"state","snapshot":"/absolute/path/color-dark.png"}}
```

The response's `radial` object includes `sessionID`, mode, group, real point,
center, owning bounds, list status, armed/neutral/outside flags, inspected and
eligible candidate IDs, keyboard/focus ownership, pending copy, current and
disabled item states, window number/frame, and accommodation flags. A closed
session reports `visible: false` and its last command result.

Run `scripts/build-review.sh --package-only`, then
`scripts/snapshot-radial.py`. The script verifies the review bundle ID
`com.austinpresley.pleaselookhere.review`, refuses an existing Review process,
starts its own disposable test instance with Accessibility denied, and quits
only that process afterward. It never launches or controls the normal app.
`TINYHAND_REVIEW_APP` may select another locally assembled bundle with that
same review ID. Output is `dist/verification/radial-v9/`: 96 PNGs with layout
JSON covering root, every child, disabled inspection, keyboard focus,
edge-unarmed held mode, held marker, list and short scrolling child lists at top and bottom,
each in light/dark and material/opaque/contrast/reduced-motion variants.
`manifest.json` records the state asserted for every image.


## Quick controls Phase C verification

Protocol remains version 1. Normal status additionally includes `browser`,
`clearRecovery` and `captureExclusion`. Browser status reports candidate, editing,
model focus, actual columns, saved favourites, cell frames, slot frames/names and
scroll geometry. Capture status reports exclusion phase, window IDs and visibility.
Recovery reports its exact opaque annotation revision, visibility and AX hiding.

`test-quick-controls` is available only with `TINYHAND_TEST_MODE=1` and a disposable
`com.austinpresley.tinyhand.radial-v9.*` defaults suite. Like `test-radial`, it calls
app/model methods and never posts native input. Request fields are strictly
validated before use:

- `surface`: `browser`, `recovery`, `exclusion`, `error`; `event` defaults to `state`.
- Browser `open`: optional `size:[width,height]`, minimum 320×180 and maximum
  1200×1000, optional boolean `editing`. Optional `query`, `scope:0|1` and selectable
  `candidate` update the browser model. `assign` uses integer `slot:0…5`;
  `finish` uses the shared finish-editing routine; `close` closes the window.
- Recovery `open` seeds one local text annotation and runs the real Clear path.
  `edit` adds a later annotation, `undo` invokes revision-checked recovery,
  `dismiss`/`close` removes the snackbar and its AX controls.
  `focus` invokes the production Command-Shift-U equivalent handler, and `undo-key`
  invokes the focused panel's Command-Z equivalent directly without posting input.
- Error `open` presents a deterministic read-only-folder failure. `dismiss`/`close`
  removes it. The error persists without taking the browser's key focus.
- Exclusion `open` invokes production closure/hiding without capturing the
  desktop. `restore`/`close` restores only valid recovery. Its snapshot is an explicitly
  labelled diagnostic witness of real visibility flags, not screen pixels.
- Optional `appearance:light|dark` affects only verification windows. Optional
  absolute `.png` `snapshot` must resolve under `APP_SNAPSHOT`; state/layout JSON
  is written beside it. No preferences, permission grants or capture access change.

The production browser opens from All pointers after radial input ownership drains,
or from Settings Pointers through Edit Quick controls favorites. Production capture
closes wheel/marker/cue/list and browser, hides recovery and excludes all retained
window IDs while owned input pairs drain. Controls stay closed after capture.
A completed image reports saved/copied output. Quick-controls command failures
persist with their reason, a Settings/Choose Folder action and Dismiss, without
taking focus or repeating the same visible announcement. Recovery returns only
for a valid revision. Command-Z/Shift-Command-Z use annotation history while
controls or recovery own focus and in Draw. Search fields keep text undo and
external Interact applications keep their own shortcuts. Command-Shift-U, also
listed under Edit > Focus Clear Recovery, focuses valid recovery explicitly;
Undo/Dismiss return to the prior visible key window and responder.


### Native Settings routes, 18 November 2026

The original section IDs remain accepted. `appearance` opens Pointer defaults;
`sound` opens its sound settings; `drawing` opens Tools with Drawing selected.
`tools` opens the remembered tool pane, while `magnification` and `screenshots`
open their named panes. `defaults`, `pointer-defaults` and `effects` are aliases
for Pointer defaults. The seven sidebar pages omit the old standalone Sound page.
A normal Shortcuts visit starts with every section closed. Practice and conflict
links reveal a specific group and focus the native control without recording.

`test-settings` is available only with TINYHAND_TEST_MODE=1 and an isolated
`com.austinpresley.tinyhand.settings-ui.*` preferences suite. It supports local
readback and disposable UI setup for scripts/verify-settings-redesign.py and is
absent from normal capabilities.

### Phase A usability verification

Visible UI calls `interact: true` **Cursor**. Selecting Cursor is idempotent;
`mode` remains the separate Cursor ↔ last tool shortcut/action. The v1 request
names, AppleScript terms, preference keys, and historical cycle order are unchanged.

In the S-023 disposable suite, `test-menu-bar.request` additionally accepts
`surface: "toolbar" | "welcome" | "practice"`, `appearance: "light" | "dark"`,
`open`, and an absolute `snapshot` path beneath `APP_SNAPSHOT`. Omitting `surface`
still targets the menu popover. Popover fixtures accept `selection: "cursor"` or
a drawing-tool raw value, `pointer`, and `permission`. Toolbar fixtures accept
`selection`, `permission`, `picker`, and `pickerSnapshot`. Practice accepts a
zero-based `lesson` in the order Click, Draw, Cursor, Quick controls. These are
view fixtures, not permission overrides for desktop actions. The popover's minimum
width is 320 points so all nine color controls retain 28-point hit targets.

The existing `test-radial.request` accepts boolean `interact` to depict Cursor or
Draw without enabling desktop input. `scripts/snapshot-usability.py` runs the Phase
A own-window matrix in fresh S-023 and radial-v9 suites and refuses to adopt an
existing Review endpoint. Run it after local tests finish, since AppKit test windows
can change key focus. Use the temporary build Python environment with Pillow to
inspect the resulting PNGs; no native input is posted.


### Phase B1 Settings compatibility and verification

The visible sidebar is `pointers`, `drawing` (Tools), `shortcuts`, `presets`,
`general`. Existing `appearance`, `defaults`, `pointer-defaults`, `effects` and
`sound` identifiers open Pointers with Defaults scope. `about` opens General.
`drawing`, `magnification`, `screenshots` still select their existing Tools pane.
No v1 operation, AppleScript term or saved preference key was renamed.

The disposable `test-settings.request` accepts `action: "inspector"` with optional
`pointer`, `scope: "this" | "defaults"`, `filter: "all" | "favorites" | "hidden"`,
and `query`. It reports `inspectorScope`, `inspectorPointer`,
`inspectorHandControls`, and the existing fields. The old `action: "customize"`
selects This inline; it no longer opens a sheet. The new-hand sheet is unchanged.
`scripts/snapshot-pointers-b1.py` starts only its own Review process with an isolated
Settings suite and temporary hand directories, calls `snapshot-settings.py`, and
captures the B1 inspector matrix without posting native input.

`scripts/snapshot-usability.py` accepts `TINYHAND_USABILITY_VERIFICATION_DIR` for
its output directory. Its default remains the Phase A folder and all existing
suite and window-capture guards remain in force.

### Phase B2/C disposable Settings fixtures

The existing test-settings operation and settings-ui suite guard remain intact.
Additional request actions invoke only local model/control methods:

- `drawing-options` with `advanced: true|false`, and `replay-drawing`.
- `suggest-add` and `suggest-undo`, invoking the same opt-in shortcut transaction
  as the visible card. Status adds suggestedResult and suggestedAddCount.
- `record` / `cancel-recording` with a mounted command, after `focus` has revealed
  its group. These call the native recorder action/cancel method directly and
  never post a key or mouse event.
- `preset-view` with optional included/recovery booleans, `import-review`,
  `restore-review`, and `dismiss-review`. The reviews use real archive/journal
  models in the disposable directory. Status adds presetNowCount/recoveryCount.
- `scroll` with bottom boolean moves the Settings document locally.
- `gesture-preview` with slot first/second changes only the mounted inspector's
  local ArmView. It does not activate a desktop overlay or write preferences.

scripts/snapshot-usability-b2c.py refuses an existing Review endpoint, uses its
own generated suite and temporary Hands/Thumbnails, captures only Settings or its
attached review sheet, verifies all 72 bundle resources, and terminates only its
own process. Its standard matrix also runs snapshot-settings.py. No normal v1
operation, AppleScript term, stored key or old test action was removed.
