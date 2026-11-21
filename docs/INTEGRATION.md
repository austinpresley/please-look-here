# Selected fork integration

This document records the 9 November integration. Austin's
[10 November feedback](FEEDBACK-2026-11-10.md) and [current backlog](STORIES.md)
take precedence for future work, including the Look Here Please name and removal
of the held interaction modifier. S-001 through S-004 are authorized for implementation. The clarified Interact
toggle in STORIES.md supersedes the historical Point/Draw controls below.

Austin selected these display ranks from the final 42-item audit on 9 November 2026. The rank and the stable research ID differ; this table is authoritative for this branch.

| Rank | Research ID | Acceptance |
| --- | --- | --- |
| 1 | C01 | Point mode forwards ordinary clicks, modifiers and drags. Draw is explicit. |
| 2 | C02 | Command-Z and an Undo action remove the last annotation. |
| 3 | C03 | Pen, rectangle, arrow and text tools work with the same drawing model. |
| 5 | C05 | A screenshot includes the hand and ink, excludes app controls, and supports copy/save. |
| 6 | C06 | Toolbar visibility is persistent; its position can be dragged, remembered and reset. |
| 7 | C07 | Number markers can be placed, moved and removed. |
| 8 | C08 | Stroke width and opacity are independent of hand size. |
| 14 | C13 | The running app exposes the validated local JSON control protocol. |
| 16 | C15 | Presentation actions have keyboard access, help and Settings controls. |
| 18 | C17 | Four line-smoothing choices preserve a responsive stroke endpoint. |
| 20 | C19 | Missing/revoked drawing permission leaves Point usable and offers recovery. |
| 21 | C20 | Each mouse press retains its route until release, including mode/activity changes. |
| 28 | C27 | Settings switches between Original and Responsive motion, with both grip-follow and scheduling behavior retained. |
| 32 | C31 | System, Light and Dark appearance and a smaller minimum pointer size work. |
| 34 | C33 | Settings groups and toolbar help expose the selected features coherently. |

The user confirmed that motion means how the hand follows the pointer, and requested a side-by-side choice over time. Original remains the initial selection. The alternate uses AiHand's larger adaptive grip-follow factors and display-linked aiming. No video, zoom, agent sessions, new artwork, localization or updater removal is selected.

Donor commits and source links are preserved in [the audit](research/tinyhand-fork-evidence.md). The integration adapts the useful behaviors into the existing native app rather than merging entire branded forks. Keep the original MIT notice. Number markers use the system font; no extra font asset is needed.

## Interaction decisions

- Point is the initial mode. The hand stays visible while native input passes through.
- Draw captures primary-button annotations. The existing held interaction modifier still temporarily forwards real input.
- A Number tool and Control-click in Draw place markers. Drag an existing marker to move it; click it to remove it. Control-click in Point remains native.
- Bare tool keys apply only in Draw while no app text editor, Settings window or shortcut recorder owns input. Command-Z is similarly scoped to annotations.
- Capture has a camera action and configurable shortcut. Right-click remains native in Point and is not assigned capture or exit.
- Text opens a small focused editor at the chosen point. Return adds the label; Escape cancels. Drawing input and bare shortcuts pause while it is open.
- Permission repair stays reachable even when the toolbar preference is off. Screen Recording is requested only on capture.
- A review build uses a separate bundle ID and install path, and contains no update feed, so it cannot replace or update the original installation.

## Verification

Run unit tests for annotation geometry/history, smoothing, marker manipulation, motion differences, mouse routing, preferences and control validation. Run local integration checks against the real app with isolated preferences. Inspect every changed Settings page in light and dark, the toolbar in Point and Draw, text entry, permission states and capture feedback. Record actual results in `docs/VALIDATION.md`; do not equate a compiled feature with a checked interaction.

## Phase A Cursor controls, 18 November 2026

The visible first tool is Cursor. It sends the existing idempotent `interact`
operation with `enabled: true`. The separate `mode` shortcut and its native menu
command remain a toggle named "Cursor ↔ last tool". Stored `point`/`draw`, tool
raw values, shortcut IDs, `interactKeepsHand`, AppleScript vocabulary, and all
control operation names remain unchanged. The UI tool order is Cursor, Pen,
Highlighter, Rectangle, Arrow, Text, Number, Eraser; the historical automation
cycle order is unchanged.

A drawing choice made in the popover or toolbar without access retains the tool
preference and a session-local pending selection. The controls show its dashed
selection, while desktop input remains in Cursor mode. Automation still rejects
unauthorized `tool` requests before changing the tool. Selecting Cursor clears
the pending selection. No drawing permission is bypassed by the review fixtures.

The floating toolbar reserves 284 points for both contexts, including up to eight
favorites plus All pointers. The Allow Drawing path is in the picker so neither
its width nor shared-button positions change. Its nonactivating panel, drag/reset,
macOS 13 visual-effect fallback, and capture exclusion remain in place. The picker
window joins the capture exclusion list and closes when the toolbar hides.

The wheel keeps every root ID, position and keyboard/list route. The `interact`
root is now visibly Cursor and always requests true. Cursor and Draw use checks;
Color uses a palette. Only the neutral root hub replaces copy with current pointer
artwork and an esc hint; inspected commands retain explanatory hub feedback.

Test-menu-bar keeps its original operation and S-023 disposable-suite gate. Its
request can now select `surface: toolbar`, `welcome`, or `practice`, and accepts
view-only `selection`, `permission`, `pointer`, `appearance`, `picker` and snapshot
fields for the Phase A matrix. The existing test-radial request accepts a boolean
`interact` as a view-only mode fixture. Neither extension installs a global input
source or changes desktop permission grants. Welcome's existing `welcomeShown`
key now uses the same preferences store as the rest of the app, isolating review
runs from the user's standard defaults domain.


## Usability icons Phase B1, 18 November 2026

The five Settings pages are Pointers, Tools, Shortcuts, Presets and General.
Legacy enum raw values, protocol names, AppleScript terms and preference keys
remain accepted. Appearance/defaults/effects and Sound routes select Pointers in
Defaults scope; About selects General. Tool subpage and practice shortcut routes
keep their previous destinations. Tools, Shortcuts and Presets bodies remain the
prior implementation, except Reset All Settings moved to General.

Favorites now means the existing toolbar pins. The read-only compatibility
adapter preserves both saved pin order and the independent six-slot
RadialFavorites layout. It writes no migration marker, rewrites no saved IDs,
and retains unavailable wheel slots. Stars, moves and enabled state never remap
those directions. Only explicit Wheel direction assignment replaces a slot or
swaps two existing wheel occupants.

Pointers uses an inline inspector instead of Customize or a separate defaults
page. Selecting any library entry returns to This. Disabled and missing-artwork
entries remain inspectable without activating them. Defaults always previews a
lavender Sample and shared policy, without per-pointer star, More or gestures.
Non-hand This states show only their own size row; existing sound and Presentation
shadow controls are retained under More > Sound and effects. The five independent
override keys and validation policy are unchanged.

Restore Artwork selects a validated replacement file and stores previous local
bytes in Hands/.ArtworkRecovery before writing. Undo refuses to overwrite later
edits. Custom rename preserves IDs and the existing manifest schema. Removal and
Undo Remove continue through HandRecoveryStore and PointerRemovalConfiguration.
No gesture artwork bundling or lookup changes belong to B1.

The compact inspector uses a transient 320-point preview reference and an inside
sample grip to fit the full hand. Desktop and practice rendering retain their
existing reference and grip behavior. Product wheel/library glyphs are drawn
native template NSImages. Practice retains local completion gating and shortcut
routing while shortening its visible text.

### Usability icons B2/C, 18 November 2026

Tools uses the visible tab names Ink, Magnifier and Capture. Their stored route
IDs remain `drawing`, `magnification` and `screenshots`. The Pen/Arrow practice
picker and paper background are local view state. DrawingPracticeSession still
owns an independent Ink document, clock and lifetime policy. Trail pen strokes
use the same InkTrail delay/speed and begin erasing during a drag. Arrows and
other shapes retain whole-mark fading. Advanced smoothing and both Trail timing
values are available in every behavior mode. Width chips are 3, 6, 10 and 16 pt;
the original 2–20 pt range and all stored values remain supported.

Suggested shortcuts are optional and never initialize preferences automatically.
The four proposals are Pointer on/off `⌥⌘P`, Quick controls hold `Option`, drawing
Undo `⌥⌘Z`, and Screenshot `⇧⌘4`. The screenshot example is deliberately marked
Skipped because that key belongs to macOS. This follows the approved mock's
conflict example instead of teaching a second screenshot key. Users can assign
another key in Presenting. No suggestion uses Control-Option. Quick controls is
one existing RadialTrigger value, never a multi-modifier chord.

A stored assignment, including an unrecognized legacy value, counts as occupied.
Suggested checks standard app commands, the app's existing assignments, enabled
macOS symbolic hotkeys through CopySymbolicHotKeys, and an exclusive Carbon
registration probe. Apply checks again and uses the existing native assignment
callbacks, including their rollback on registration failure. The result counts
actual additions, occupied commands and skipped proposals. Undo restores the
exact prior shortcut dictionaries, display strings, modifier hold and absent
keys. This Undo is session-local. Existing assigned shortcuts are unchanged.
The catalog has 26 commands in its original groups, plus Toolbar and Stream Deck
setup. Search count and group assigned counts are derived from the catalog.

Preset Now compares the current portable PresentationSetup, including pointer
identity, ordered toolbar and wheel favorites, semantic per-pointer overrides,
ink and sound. Hidden pointer order and JSON key order do not affect matching.
Selection never applies a preset. Apply and each card's More actions remain
separate. Rename changes only the name, retaining the saved setup and identity.
The Undo last change row is always present and reads the existing durable journal.

Recovery copies lists durable transaction journals. Its Restore review names the
settings and preset/artwork files that will be replaced. This is separate from
existing conflict-checked Undo. A reviewed older restore captures the current
portable preferences and affected files, rejects changes since review, and writes
a durable safety journal before replacement. If that copy cannot be saved,
restoration does not proceed. Undo of the restore recovers that saved state.
The existing version 1 backup, setup, preset and recovery encodings are unchanged.
No migration or saved-key rename is required. Backups include presets, pointer,
ink and sound settings, custom hands and custom gestures. Built-in artwork ships
with the app. Shortcuts, capture folder, startup and window positions stay local.
Import retains its existing validation, staging, review and recovery-first commit.

Phase C adds `assets/gesture_<id>_ok.png` and `gesture_<id>_shaka.png` for each of
36 built-in hands. First maps to OK and second to Shaka. These are complete
1024×1536 canvases. The existing scripts/lib.sh `gesture_*.png` copy packages them
beside `hand_*.png`; Package.swift still relies on app packaging rather than a
second SwiftPM resource bundle. Lookup is custom per-hand file, bundled per-hand
canvas, then generic starter composition. Custom hands keep generic composition
unless custom gesture artwork exists. Non-hand pointers have no gestures. A
corrupt custom gesture stays unavailable rather than silently replacing the
user's choice. Restore removes only that custom slot and reveals its bundled
pose or generic fallback. Full canvases bypass makeGesture/composeGesture and
reuse base HandAsset anchors, crop and rod geometry. Cache signatures include
the per-hand bundled resource, generic fallback and applicable custom file/base.
The approved one-row plush and robot bottom trim is retained.

scripts/bundle-gesture-art.py checks manifest acceptance and source hashes, then
recompresses only IDAT. It preserves every other PNG chunk and asserts identical
decompressed filtered pixel bytes. The original design folder is untouched.
The reproducible audit is in dist/verification/usability-icons-phaseB2C/.
