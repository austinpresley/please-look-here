# Native app structure

TinyHand is one SwiftPM executable with AppKit windows, SwiftUI Settings and Core Animation pointer rendering. Its deployment target is macOS 13. This existing app remains in Swift 5 language mode under the installed Swift compiler.

The integration separates annotation geometry/history, its layer rendering, per-button event routing, screenshot capture, pointer motion and the local control transport. UI composition stays in the application and overlay controllers. Settings changes publish one native preferences notification. The input tap runs on its own thread; UI work returns to the main queue.

See [the integration scope](docs/INTEGRATION.md) and [the architecture review](docs/architecture-review-2026-11-09.md). Local verification commands and measured results live in `docs/VALIDATION.md`.

Pointer eligibility belongs to `PointerCatalog`. It keeps the complete library,
per-ID enabled state, file availability and toolbar favorites separate. Settings,
local JSON control and AppleScript selection validate through this module before
mutation. The overlay owns selection repair and a one-second catalog refresh on
the main run loop; hand metadata reloads there, and image validity is cached until
its file signature changes. `selectableStyles` supplies every enabled, available
choice in stable library order for cycle/radial actions. `quickStyles` only
filters toolbar favorites, with a temporary first-choice fallback when needed.

The separate `LookHerePleaseDeck` executable keeps Stream Deck feedback distinct
from app commands. `KeyModel` sends an app-owned `toggle` without a sampled style
or activation target. `DeckPlugin` serializes requests, polls acknowledged state
and refreshes app-exported thumbnails while pointer keys are visible. Only changed
artwork invalidates cached key faces. Input, pending, receipt and persistent-state
marks remain independent. The read-only toggle inspector never writes saved key
settings. The app's pointer catalog remains the selection authority.


Choose Pointer sends the style-free `cycle-pointer` operation. ControlBridge runs
it atomically on the app main queue, refreshes custom manifest membership and
resolves `PointerCatalog.nextSelectable(after:)` from the full selectable catalog.
It preserves activation and Interact. Existing pinned navigation remains separate.
The plugin's `CycleQueue` holds unsent press intents in FIFO order across cycle
keys. Key releases distinguish deliberate presses from duplicate keyDown. Only
one cycle request is outstanding; uncertain sent intents are never replayed and
unsent intents wait for a later successful status read. Key incarnation IDs prevent
an old completion from changing feedback on a replaced key. The new read-only
cycle inspector needs no saved settings; legacy fixed-selection UUID/settings stay
unchanged. The S-019 toggle pending suppression is independent of the cycle queue.

Choose Tool uses the existing app `tool` operation for fixed choices and the new
field-free `cycle-tool` for atomic next-tool selection. `DrawingTool.next` follows
toolbar order and wraps. ControlBridge validates capture and Accessibility before
calling the same overlay tool-selection path as the toolbar, preserves pointer
activation/selection and turns Interact off. Capture and permission rejections
return distinct reasons without partial state changes.

The plugin's typed `SelectionCommand` is copied into each `CycleQueue.Intent` at
press time. Pointer cycles, tool cycles and fixed tools share the FIFO; inspector
changes cannot retarget waiting presses. Existing pointer UUID/settings and toggle
suppression remain intact. `Observed` consumes the app's tool and capture state
without treating missing values as defaults. The tool key's actual tool, activation,
Interact and readiness remain independent of transient input/command feedback.
The native labeled inspector select validates saved choices without silent repair.


Settings installation is separate from Stream Deck key behavior. `StreamDeckPackage`
validates the signed app's installer receipt and exact archive hash; the main-actor
`StreamDeckInstaller` discovers the host and hands that archive to NSWorkspace.
Hashing runs off the main actor. Injected host/version/open functions make missing,
old, corrupt, failed and pending paths testable without changing host data. The
handoff never writes profiles/keys or claims success from a successful open. The
local packaging helper owns the source/version/hash contract before app signing
and verifies it again from the delivered ZIP. KeyModel, CycleQueue and control
operations are unchanged by S-022.


The S-013 radial module separates three owners. `RadialSession` is pure gesture
and fixed geometry state, with bounded six-item pages from the complete enabled
catalog. `RadialMenu` owns the nonactivating native panel, accessible buttons,
selection dot, measured layout output and brief result feedback. `RadialInput`
owns the modifier latch and swallowed mouse/Escape pairs under a lock. The
existing InputTap calls it before annotation routing, on its existing tap thread;
ordered main-queue notifications update the menu. There is no second tap and no
modifier-to-Interact path. Only flags changes sample native button state; ordinary
pointer movement moves the dot without rebuilding unchanged buttons.

OverlayController supplies activation, permission, capture, menu and text/focus
eligibility. Catalog/preferences changes dismiss stale sessions. Claimed releases
keep the tap enabled until they drain even after deactivation or trigger clearing.
The router passes flags and ordinary keyboard pairs unchanged, cancels on another
key/extra modifier, and requires a fresh modifier gesture after selection. A trigger
pressed during an existing drag cannot open until it releases and presses again.

Radial commands enter the same ControlBridge handler as local clients, so pointer
validation, tool permission/capture checks and atomic preference batches stay
app-owned. Pointer/color submenus add ordinary keyboard menu access without
redesigning the status menu. The test-only comparison/snapshot operation requires
both test mode and the isolated S-013 suite prefix. Normal capabilities omit it.

S-023 moves status-item, native popover and secondary menu composition into
`MenuBarControls` and `MenuBarCommands`. AppDelegate supplies the same ControlBridge
request handler used by radial/automation and keeps application setup and hotkey
registration. Neither new presentation module writes preferences or changes
activation directly. Switches, selection, menu checks and availability reconcile
from OverlayController, PointerCatalog and Preferences after every action and
while controls/native menus are open. The native chooser uses selectableStyles,
with no pin writes. The current tool remains selected while its readiness is
reported separately from Pointer and Interact.

`ControlInput` runs under the existing InputTap lock before new radial/annotation
claims. Already-owned radial pairs are offered to RadialInput first, using its
read-only ownsPair query. Repeated downs for existing captured drawing presses
also remain with that owner. A new surface cannot steal repeats and consume the
matching up for an older owner; otherwise a held radial Escape or drawing press
could remain owned after controls close. The controls own outside-dismiss and Escape pairs, including repeats,
until matching releases. Status-item clicks begun with controls open are also
owned as whole pairs and commit on release; forwarding the release after native
transient dismissal leaked a fixture mouse-up in the initial native test. The tap
stays enabled for retained ownership after closure/deactivation. Unclaimed pairs and native control/menu item clicks keep their original routing.
For a mouse-down during native menu tracking, the existing tap reads only this
process's live native menu rectangles from Window Server. It consumes outside
dismissal instead of allowing AppKit's conventional click replay to the fixture.
The query runs only on those rare presses, never on pointer movement. Closing
cancels all tracking menus and retains the release owner. No
second tap, global shortcut or held-Interact path is added.

MenuBarControls owns one suspension lease spanning its popover and the set of
tracking native menus. A secondary status menu requested by the tap callback is scheduled
with RunLoop.main.perform, after the main dispatch callback returns. Beginning a
nested native tracking loop inside that dispatch callback blocked control-server
requests until dismissal; the focused right/Control-click regression proves state
reads and external pointer/sound changes remain live while it is open. The More
control is a native NSPopUpButton pull-down with an icon face. Its AX Menu Button
Press returns success while the menu opens; a custom NSButton with NSMenu.popUp
kept the AX reply waiting through the tracking loop. Overlay deactivation does not erase that presentation
lease. Settings/capture close the popover before their shared action. A key app
window independently blocks drawing and radial input; closing it resumes normal
eligibility on the existing service tick. Native controls/material and disabled
popover animation respect appearance and accessibility display preferences.
Verification-only anchors/narrow width/snapshots require test mode and an S-023
suite. They do not move the real status item, displays or saved toolbar position.
