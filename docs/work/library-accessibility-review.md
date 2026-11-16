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

## S-046 implementation

The page now orders the compact toolbar pins, pointer library, then selected-pointer details. The gallery appears before gesture editing. Its native scroll view is capped at 320 points and shrinks for short result sets. Fixed tile widths leave space for an always-visible native scrollbar and keyboard focus rings. Search and the Enabled, Pinned and Custom checkboxes appear above results.

`PointerLibraryFilter` intersects all active filters and searches names and stable IDs without changing catalog order. Search trims whitespace and uses localized, case/diacritic-insensitive matching. Enabled tests the saved enabled flag rather than artwork availability. Pinned includes disabled or unavailable favorites. The query, checkbox state and measured gallery height use view-local State. They do not write preferences. Clear Search clears only the query, Reset Filters clears only the checkboxes, and the empty-result action clears both. A result count and hidden-current-pointer message explain what the filters show without replacing selection.

Tiles show separate Enabled and Pinned/Not pinned controls. The pin icon changes shape and the selected pointer has a checkmark, Selected text and an outline. Control labels and accessibility values distinguish enabled state, pin state and selection. Pinning still uses SettingsModel's existing maximum-capacity and last-pin constraints. Enabling and selection still validate through PointerCatalog.

HandRecoveryStore, removal/Undo behavior and the persistent Undo button above the library are preserved. Undo is outside the filtered grid, so an empty result does not hide recovery.

### Selected-pointer override integration location

In `Sources/TinyHand/PointerLibrary.swift`, `SelectedPointerDetails.body` has an explicit insertion comment between the selected-pointer heading and `HandGestureSettings(model: model)`. Place the separately developed PointerCustomization controls there after merging their model and choosing the actual initializer. This branch intentionally declares no PointerCustomization type and has no references that require that other agent's files. HandGestureSettings continues reading the saved pointer, so selecting a tile updates gesture editing; filtering alone does not retarget it.

### Local evidence

`swift test --filter 'PointerLibraryFilterTests|SettingsAccessibilityTests|HandRecoveryTests'` passed 13 tests across four suites, including the existing HandRemovalSettingsTests persistent Undo test. The final focused run used an isolated defaults suite, hand directory and thumbnail directory under `/tmp/lhp-library-filters.bspnMS`. Log: `/tmp/lhp-library-filters.bspnMS/test.log`.

New filtering tests exercise all eight Enabled/Pinned/Custom combinations, positive and negative search intersections, case and accent matching, stable-ID search, whitespace, empty catalogs/results, independent reset behavior, disabled pins, unavailable enabled artwork and preserved saved selection/pins/disabled IDs. A complete preferences snapshot remains equal before and after filtering.

The same pre-existing test compilation correction described for S-045 was applied temporarily for this run and restored afterward. It is not included in this branch's changes. PointerLibrary and PointerLibraryFilter pass grid lint; `git diff --check` passes. `swift build --product TinyHand` passed on the restored source tree with no warnings. Log: `/tmp/lhp-library-build.LbuHfz/build.log`. `xcrun vtool -show-build` confirms the resulting TinyHand executable has `minos 13.0`.

### Parent acceptance still required

Verify search typing without initial forced focus, Tab/Space operation of filters and tiles, native scroll/focus behavior with Show scroll bars set to Always, all filter combinations, empty/reset actions, selection retained when hidden, distinct enabled/pinned cues, and selected details following selection. Verify the persistent Undo button with filters active and after reopening Settings. Check active light/dark windows, Increase Contrast, actual VoiceOver announcements and pin named actions, and drag reorder/removal with the new small menu buttons. No GUI, VoiceOver, input automation, signing, notarization, install or packaging was performed here.

### Copy and glossary proposals

- Enabled / Pinned / Custom filters: independent checkboxes combined as an intersection. Enabled and Pinned retain their existing separate meanings.
- Clear Search: clear only the current query.
- Reset Filters: turn off Enabled, Pinned and Custom filtering while retaining the query.
- Reset Search and Filters: return the browser to the whole library.
- No matching pointers: no library entries satisfy the current search and filters.
- Selected pointer details: controls for the saved pointer, shown after the gallery even when filters hide its tile.
