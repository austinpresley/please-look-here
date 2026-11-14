# Selected fork upgrades

Austin authorized numbered items 1, 2, 3, 4, 7, 9, 10, 12, 13 and 14 from the 14 November shortlist. This milestone takes precedence over older unselected ideas. Implement in the existing native app, make routine product choices autonomously, and verify builds and packaging locally. Hosted CI remains disabled.

The existing local review app is preserved separately in recovery archive `/Users/apresley/Library/Caches/look-here-please-fork-upgrades-20261114/working-tree-before.tar.gz` and local checkpoint commit `8451227`. New work uses `feature/fork-upgrades-20261114`.

| Story | Shortlist | Acceptance and UX decision | State |
| --- | --- | --- | --- |
| S-026 | 1 | Audio engine operations run off the main thread, recover after output changes or unrendered buffers, and stop cleanly. Existing sound choice is retained. No new UI. | doing |
| S-027 | 2 | Lock, sleep, screensaver and session resignation deactivate the pointer, restore the system cursor and dismiss transient controls. Captured releases drain safely; activation is never restored automatically on wake. | todo |
| S-028 | 3 | Overlay and floating controls recover both on activation and Space/display changes. Hidden-toolbar preference remains authoritative; recovery never opens Settings. | todo |
| S-029 | 4 | A still pointer stops high-frequency motion work after settling. Native movement/input wakes it; permission and catalog maintenance continue at low frequency. Original and Responsive remain available. | todo |
| S-030 | 7 | Drawing offers Whole line fade, Trail and Keep until cleared without losing saved timing. Trail erases pen strokes from their start while drawing, preserves semantic Undo/Redo and clears timers on reset. Settings inline controls expose delay and speed. | todo |
| S-031 | 9 | Magnification is an optional presentation action reachable from native controls and an unassigned shortcut. A circular loupe follows the cursor, with adjustable zoom/diameter in Appearance. Capture excludes our app, switches displays safely, starts only on demand, and stops on hide/deactivation/error. Permission failures are recoverable and leave Interact usable. | todo |
| S-032 | 10 | Optional temporary hand poses work with built-in/custom gesture assets, a discoverable native chooser and user-assigned hold shortcuts. Release/cancel/window changes restore the normal hand. No gesture steals native mouse routes or adds factory hotkeys. | todo |
| S-033 | 12 | Appearance has an optional Tap swing slider, separate from Original/Responsive follow motion. Zero preserves the current tap; larger values add a wind-up/strike/settle. Drag contact is immediate and Reduce Motion suppresses swing. | todo |
| S-034 | 13 | Custom hand creation explains image requirements, provides a reusable creation prompt, previews validation and imports a valid hand without losing existing hands. Native paste/open/save controls remain available, with inline errors and a clear route back. | todo |
| S-035 | 14 | Sound offers nine additional tap choices with previews and packaged WAV files. Existing choices/defaults and per-pointer sound rules remain. The native grid scrolls only when needed and is readable in light/dark. | todo |

Each story uses the existing Settings pages and command model. New preferences have conservative defaults; current hands, pins, enabled choices, shortcuts, Stream Deck profiles and signing identity are preserved. New optional features start off or unassigned. Donor release feeds, identities and hosted workflows are excluded. The audit preserves exact donor references in `docs/research/tinyhand-fork-update-2026-11-14.md`.

Implementation progress: all ten selected areas are wired into the app. Thirty-three focused tests pass across audio, lifecycle, trail ink, magnifier, gesture, tap swing and shortcut behavior. Native UI/runtime review and final packaging are still pending; the table is not yet a completion claim.

Gesture UX decision: two fixed gesture slots start with the positive OK and Shaka artwork, adapted to the current hand's wrist/stick geometry. Each hand can replace either slot with its own imported pose. Gestures never become pointer catalog IDs. This brings over item 10 without adding the unselected Line art base hand from item 11. Hold shortcuts are unassigned; native menus provide two-second previews. A small contrasting dot keeps the real click location clear during non-pointing poses.

Magnification UX decision: an independent toolbar/menu command, optional unassigned shortcut, 3x initial zoom and 240-point lens. It follows the current display with a cursor marker, pauses for owned controls, preserves a frozen lens for non-toolbar screenshot capture, and stops on pointer/system shutdown. Startup and frame failure leave normal interaction usable.

Validation uses isolated preference and hand directories, unit tests for lifecycle/geometry/state, native fixture input, active light/dark window captures, and the existing signed/notarized universal packaging lane. Known physical-device and older-OS limits stay explicit.
