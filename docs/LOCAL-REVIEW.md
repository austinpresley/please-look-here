# Local review checkout

These instructions describe Austin's combined local review source. They do not
describe the functional source currently published on remote main.

## Build and install the review app

All builds, tests and packaging run locally on the Mac. Hosted CI stays disabled.
Icon generation requires Pillow in the active Python environment, librsvg
`rsvg-convert`, and Xcode Icon Composer. Run `python3 scripts/make-icons.py` for
packaged art and `python3 scripts/make-branding.py` for presentation exports.

```sh
bash scripts/run-tests.sh
bash scripts/build-review.sh --open
```

The build requires `Developer ID Application: Austin Robinson (G2R8798RLT)` and
Keychain notarization profile `look-here-please`. `CODESIGN_IDENTITY` can select
an explicit Developer ID Application identity on that same team;
`NOTARY_PROFILE` can select another configured Keychain profile. Missing signing
or notarization credentials fail the build. There is no ad hoc fallback.

The helper first builds, validates and notarizes the matching Stream Deck plugin,
then embeds its installer and version/hash receipt before signing the app. It
signs with hardened runtime and a secure timestamp, requires Accepted
notarization, staples the ticket, checks Gatekeeper, and validates an extracted
copy of the final ZIP. It installs the complete app at
`~/Applications/Look Here Please.app`; `--open` launches that installed copy.
The deliverable is `dist/Look Here Please-review.zip`. Use `--package-only` to
validate packaging without installing. `build-app.sh` and `release.sh` use the
same local lane; they do not publish updates.

The bundle identifier `com.austinpresley.pleaselookhere.integration`, executable
`TinyHand`, settings domain and `Application Support/Please Look Here/Hands`
directory stay stable. No migration or upstream update feed is included.
Compatible signing identity is checked against the installed app before replacing
it. Permission continuity requires a two-build runtime check with normal LaunchServices
launches. Direct GUI execution from an agent shell can inherit the caller's
permission responsibility and is insufficient evidence. See [validation](docs/VALIDATION.md).

## Automation

- [AppleScript](docs/applescript.md) controls the pointer, Interact, pointer selection and drawing tool.
- [Stream Deck](docs/streamdeck.md) keys control the pointer and show its actual state. Install the bundled plugin from **Settings → General → Install Stream Deck Plugin…**, then confirm in Stream Deck.
- The [local control protocol](docs/control-protocol.md) serves JSON clients.

## Use

Click the menu bar icon for compact controls. Pointer On/Off and Interact are
separate switches. Choose Pointer includes every enabled, available choice,
including unpinned and custom hands. Selecting a pointer keeps activation and
Interact unchanged; selecting a tool turns Interact off without turning Pointer on.
Right-click or Control-click the icon for grouped Pointer, Drawing and Presentation
commands, Settings and Quit. More Commands opens the same native menu from the
controls. Escape, the icon or an outside press closes the controls. The menu bar
remains usable when Show toolbar is off.

Settings → Shortcuts starts with every presentation and tool command Unassigned.
Click a shortcut control, then press keys to assign it. Clear removes the
assignment immediately and across relaunches. Reset All clears every assignment.
Explicitly saved assignments from older versions remain; implicit presets do not.

Pointer on/off and Clear Drawing assignments work globally. Other assigned
presentation commands work while the pointer is on; tools and annotation Undo/Redo
also require Interact off. These commands pause in app windows and annotation text
editors. No global Settings, Undo/Redo or Escape binding is installed by default.
Use the toolbar or menu for commands you leave unassigned, including turning the
pointer off. Standard editing keys and Command-comma remain available in app
windows. Escape cancels native editors and menus.

Interact is one switch in General, the toolbar and the menu. On lets native
clicks, modified clicks, drags and typing reach the underlying app. Off captures
annotations with the same pointer. No held modifier changes this state.

Keep the hand visible while interacting is enabled by default. When disabled,
the hand hides during native clicks and drags, then reappears after all buttons
release. Existing saved choices are respected.

Number markers can be placed with the Number tool or Control-click. Drag one to
move it; click it to remove it. Text opens a focused editor; Return adds the label
and Escape cancels. Clear Drawing and marker edits participate in Undo.

Drag the toolbar handle to move it. Right-click the handle, or use Appearance →
Reset Position, to recenter it. Settings → Drawing controls line width, opacity,
smoothing, color and fading independently of hand size.

Settings → Appearance → Motion offers Original and Responsive. Original keeps
the existing grip swing. Responsive follows more closely and uses a display link
on macOS 14 or later. macOS 13 uses the same responsive grip with the timer fallback.

Settings → Appearance → Pointer → Shadow style offers Original and Contact.
Contact rests with a lighter, diffused shadow, then gathers beneath the fingertip
as you tap and softens again on release. The shadow fades toward the lifted hand
and rod. The existing shadow switch controls either style; the laser keeps
its own glow. Original remains the default for existing settings and Reset All.

Screenshots include annotations and the pointer while omitting app controls.
The camera button temporarily hides the hand so it does not point at the camera
control in the image. Choose clipboard, folder output, or both in General.

Drawing requires Accessibility. Screenshots require Screen Recording. General
shows permission state and links to the relevant system settings. Interact remains
available without drawing permission.

When comparing two pointer apps, run one at a time or give them different global
shortcuts.

## Local automation and verification

The executable exposes a versioned JSON interface over a same-user private socket.
Run its `--help`, then read [the control protocol](docs/control-protocol.md).

[Validation results](docs/VALIDATION.md) record local unit, native-input, UI and
packaging checks. [Architecture](ARCHITECTURE.md) describes the modules. The
[complete fork audit](docs/research/tinyhand-fork-evidence.md) preserves donor
commits and source references.

## Credits and license

Based on [TinyHand by Kamran Ahmed](https://github.com/nilbuild/tinyhand).
Selected ideas and implementation references come from the forks credited in the
audit. The original MIT notice is preserved in [LICENSE](LICENSE).


Quick controls can open at the cursor while a modifier is held. Assign or clear
one in **Settings > Shortcuts > Quick controls at the cursor**. It starts
Unassigned. With the pointer on, hold the modifier alone, move through Pointer,
Color or Tools to an outer choice, then release to select. Move inward to go
back. Center release, Escape or an outside click cancels. At a display edge,
enter the shifted center first. Pointer choices include every enabled, available
hand and Laser dot, in library order, across pages of six. The toolbar remains
optional. Other keys close Quick controls and preserve their usual shortcuts.
