# Settings keyboard access and pointer library

Assigned S-045 and S-046, recommendations 10 and 11 in the 15 November milestone. Work is confined to `t3/settings-accessibility-pin-navigation` at `/Users/apresley/.t3/worktrees/Please Look Here/t3-ae3cbfae`. Swift 5 language mode and the macOS 13 deployment target remain unchanged.

## S-045 implementation

Settings uses a native sidebar List with stable section tags and selection binding, so native arrow-key navigation can change pages. No initial focus is assigned. The existing Settings window's `makeFirstResponder(nil)` remains unchanged.

Each toolbar pin has a visible native actions menu with Move Left, Move Right and Unpin from Toolbar. The artwork remains the drag target, avoiding native menu tracking across the whole tile. Menus disable impossible boundary moves and prevent removal of the last pin. VoiceOver has labeled menu values with pin position and enabled state plus named Move Left and Move Right actions. A request at a boundary is a no-op, including named accessibility actions. Moves preserve pin membership, capacity, enabled state and saved pointer selection. They cannot interrupt an in-progress drag.

Ink swatches are keyboard-focusable native buttons with color labels, selected values/traits and a visible checkmark. Sound tiles also announce selection and show checkmarks. Reusable link, text and pill buttons, pin-picker controls and the Laser dot sound switch no longer exclude keyboard focus. Native button styles provide focus cues. Link rows expose their title and detail. Existing shortcut recorder values remain native.

### Local evidence

`swift test --filter SettingsAccessibilityTests` passed both tests in an isolated `TINYHAND_DEFAULTS_SUITE`, with `TH_HANDS_DIR` and `TH_THUMBNAILS_DIR` under `/tmp/lhp-library-accessibility.JqVUNW`. Log: `/tmp/lhp-library-accessibility.JqVUNW/test.log`. These tests cover left/right pin moves, missing IDs, empty/sole-pin orders, boundaries, preserved selection and disabled IDs, and drag ownership.

The first test attempt found a pre-existing compile error at `Tests/TinyHandTests/PointerCatalogTests.swift:229`. `CustomHands.remove` now throws but this defer does not handle errors. Tests passed after temporarily changing it to `_ = try? CustomHands.remove(custom)`. That unrelated correction is excluded from the commits and must be applied by the parent before integrated tests. Original failure log: `/tmp/lhp-library-accessibility.QIwlE9/test.log`.

Grid lint passed for SettingsView, SettingsComponents and SoundSettings. PointerSettings has 27 pre-existing off-grid lines, compared with 30 in the base revision. No wholesale layout cleanup was performed. The new menu uses the existing drag row geometry. `git diff --check` passed.

### Parent acceptance still required

No GUI was launched, no native input was posted, and no VoiceOver or hardware keyboard checks were performed. The parent must verify sidebar arrow navigation, Tab order, Space activation, visible focus cues, pin menus and named VoiceOver actions, drag reorder/removal, Escape dismissal, selected announcements and checkmark contrast. Test normal and Full Keyboard Access behavior and both appearances on a real active Settings window. Layout probes, snapshots, packaging and release checks remain parent-owned.

### Copy and glossary proposals

- Move Left / Move Right: move a toolbar pin by one adjacent slot without changing pointer selection or enabled state.
- Toolbar pin actions: the native menu for one favorite's ordering and removal.
- Selected swatches and sound tiles use a checkmark as well as color and an accessibility selected value.
