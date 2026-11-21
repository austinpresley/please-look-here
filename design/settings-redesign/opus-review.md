# Settings redesign: independent UX review (Opus 5.5)

Proposal only. No app code, shared docs, builds or snapshots were changed or run.
Sources read: `SettingsView.swift`, `SettingsWindow.swift`, `SettingsComponents.swift`,
`SettingsModel.swift`, `PresentationSettings.swift` (General, Shortcuts, Appearance,
Drawing), `PointerSettings.swift`, `PointerLibrary.swift`, `PointerCustomization.swift`,
`PointerPreview.swift`, `PointerBrowser.swift`, `HandMakerSettings.swift`,
`HandGestureSettings.swift`, `MagnificationSettings.swift`, `SoundSettings.swift`
(Sound, About), `PresetsSettings.swift`, `StreamDeckInstaller.swift`, `Updater.swift`,
`MenuBarCommands.swift`, `docs/BRIEF.md` and `docs/GLOSSARY.md`. The 15 Nov certified
snapshots in `dist/verification/app-review-20261115/settings-certified/` were viewed
read-only.

## Diagnosis: why it feels messy

1. **Pages are sorted by when features shipped, not by user task.** Appearance holds the
   app theme, pointer defaults, motion, magnification and the floating toolbar
   (`PresentationSettings.swift:140-209`). Sound holds a second half of the same
   "Pointer Defaults" (`SoundSettings.swift:27-46`). "Pointer Defaults" is one glossary
   concept split across two pages.
2. **Live state appears as settings.** The Interact switch (`PresentationSettings.swift:15`)
   and "Selected tool" (`:217`) are runtime modes that the menu bar, toolbar, Quick controls,
   shortcuts and Stream Deck already own. In Settings they look like preferences, and the
   Interact toggle can fail with an inline message.
3. **Pointers holds four tools on one scrolling page.** It contains the toolbar pin strip,
   a library with search, three filter checkboxes, Clear Search and Reset Filters buttons,
   a count, a hidden-selection note and a nested 320 pt scroll grid. Each grid cell has
   four controls. Below that are the per-pointer override form (seven rows, each with a
   Use Default button) and gesture artwork. The hand maker replaces the page through a
   breadcrumb state (`SettingsView.swift:109-122`). "Make your own" has three entry
   points. `PointerBrowser` is a second searchable library in a separate window.
4. **Too much help text, with the important parts mixed in.** Shortcuts opens with a
   37-word paragraph and adds two more paragraphs in the Quick controls card
   (`PresentationSettings.swift:76, 89-92`). The gesture card adds another (`HandGestureSettings.swift:49`).
   Library rows carry two explanation lines (`PointerLibrary.swift:21, 114`). Presets
   shows a raw pointer ID: `Selected pointer: \(selected.setup.selectedID)`
   (`PresetsSettings.swift:159`). Every row's caption has the same visual weight, so
   nothing stands out.
5. **Shortcuts is a flat list of about 26 "Unassigned" rows.** The "Pointer and drawing"
   card mixes 13 commands (`:98-107`). Names are inconsistent ("Turn pointer on or off" /
   "Turn Pointer Off" / "Toggle Interact" / "Show / Hide Toolbar"). Per-row conflicts exist
   (`SettingsComponents.swift:189`), but the page has no summary, so the menu item
   "Review 2 Shortcut Conflicts…" lands at the top of a long page.
6. **Paired switches that disable each other.** "Copy to clipboard" is disabled when Save
   is off, and Save is disabled when Copy is off (`PresentationSettings.swift:48,52`).
   A greyed-out switch with no reason reads as a bug.
7. **Updates are split and silent.** The auto-check switch is under General › Startup and
   "Check for Updates" is in the About header. Both disappear when `Updater.isAvailable`
   is false, which is the case for every local review build without `SUFeedURL`
   (`scripts/lib.sh:20-30`). Nothing shows the last check time or why updates are
   missing. `automaticallyChecks` returns `false` when the controller is nil.
8. **Permission rows are named for features, but the buttons always look the same.**
   "Drawing" maps to Accessibility, which Quick controls also need (that requirement is
   stated only in Shortcuts). "Review…" is shown whether or not the permission is
   granted, and the Accessibility button triggers the system prompt even when trust is
   already granted (`PresentationSettings.swift:35-38`).
9. **Reset all settings is in About** (`SoundSettings.swift:128`), next to the credits.
10. **The whole window re-renders every second.** `SettingsWindow.swift:85` calls
    `model.refresh()` once a second. That bumps `revision` and re-evaluates every visible
    page. `PointerCustomization.override` and `PointerPreview.hasCustomizedAppearance`
    reload `PointerConfigurationDocument` from disk on each render, and `AXIsProcessTrusted()`
    runs in the body. This is the settings-UI side of update reliability (see P5).

## Target navigation: 8 pages → 7, ordered by task

| Before | After | Why |
| --- | --- | --- |
| General | **General**: permissions, screenshots, startup and updates, app appearance | Housekeeping only; no live modes |
| Shortcuts | **Controls**: Quick controls, Toolbar, Keyboard, Stream Deck | Every way to trigger commands, in one place |
| Drawing | **Drawing** | Same scope, preview first, advanced fade behind a disclosure |
| Pointers | **Pointers**: current pointer, favorites, library | Choosing pointers; per-pointer editing moves to a sheet |
| Appearance | **Effects**: defaults for every pointer (size, shadow, motion, tap swing, sound, magnification) | Yes, rename it. It is cursor behavior, not app appearance |
| Sound | *(removed)* → Effects › Sound | Five controls, half of them duplicated in Pointers; too small for a page |
| Presets | **Presets & Backup**: presets, backup, undo, reset | Holds every configuration-level action, including Reset |
| About | **About**: identity, version and credits only | Reset and Updates move out |

Sidebar order: General, Pointers, Effects, Drawing, Controls, Presets & Backup, About.
Keep `SettingsSection` raw values (`.shortcuts`, `.appearance`, `.sound`) as aliases that
redirect, so `showShortcut(_:)`, `ControlBridge` `section` requests,
`MenuBarCommands` ("Allow Drawing…" → general, "Review Shortcuts…" → shortcuts,
"Edit Gesture Artwork…" → pointers) and practice destinations keep working.

Page-wide pattern: one short subtitle under each page title. Row captions only where a
control is ambiguous. Advanced controls go in a native `DisclosureGroup` that remembers
its state. Status uses a symbol chip (✓ / ⚠), not prose.

---

## General

**Before:** Getting started · Using the pointer (Interact, Keep hand visible) · Stream Deck
· Permissions · Screenshots (two interlocked switches, folder) · Startup (login, auto-update).

**After**

*Subtitle:* "Permissions, screenshots and startup."

1. **Permissions** (first, because it controls what works)
   - `Accessibility` ✓ Allowed / ⚠ Not allowed. Caption: "Needed to draw, use tool keys and Quick controls." Button only when not allowed: **Open System Settings…**
   - `Screen Recording` ✓ / ⚠ / "Not requested yet". Caption: "Needed for screenshots and magnification." Button **Open System Settings…** when not allowed.
   - When granted, show the chip and no button. Don't call `AXIsProcessTrustedWithOptions(prompt:)` once trust is granted.
2. **Screenshots**
   - `After capturing`: popup **Save and copy / Save to folder / Copy to clipboard**. This replaces the two interlocked switches and maps onto `captureSaves`/`captureCopies`. The invalid both-off state can no longer be chosen.
   - `Folder`: path control showing "Captures", with **Choose…**. Hidden when "Copy to clipboard" is selected.
3. **Startup and updates**
   - `Open at login` switch.
   - `Check for updates automatically` switch · **Check Now** · caption "Last checked today at 9:41" (Sparkle `lastUpdateCheckDate`).
   - Review builds without a feed show one disabled line: "Updates aren't set up in this build." Don't hide the section.
4. **App appearance**: `Theme` System / Light / Dark (moved from Appearance). Caption: "Applies to Settings, the toolbar and menus."
5. Footer link row: "New to Look Here Please? **Practice the Controls…**". The Getting started card shrinks to a single link.

**Moved out:** Interact switch → removed from Settings. Its destinations are the menu bar
Interact switch, the toolbar, the Toggle Interact shortcut, Quick controls and Stream Deck.
· Keep the hand visible while interacting → Effects › Motion · Stream Deck → Controls.

---

## Pointers

**Before:** toolbar strip, then a library with heavy filters and a nested scroll, then
per-pointer overrides (seven rows with Use Default), then gestures, plus the in-page hand maker.

**After**

*Subtitle:* "Choose your pointer and favorites. Defaults for every pointer are in Effects."

1. **Current pointer** header card: a 96 pt live sample (reuse `PointerPreviewCanvas`),
   the name, a "Customized" chip when overrides exist, and **Customize…**, which opens a sheet.
2. **Favorites**: two rows with matching layouts.
   - `Toolbar`: the existing 6-slot strip (drag, +, pin menu). Caption on one line: "Drag to reorder. Drag out to remove."
   - `Quick controls`: six small N/NE/E/SE/SW/W slots, read-only, with **Edit…**, which opens `PointerBrowser` in editing mode. This makes visible that the two favorite sets are separate, which the library caption currently has to explain.
3. **Library**
   - Header: search field, a single **Show** popup (All / Enabled / Pinned / Custom), and **New Hand…**. Remove Clear Search (the field has its own clear button), Reset Filters, the count line and the "Combine filters…" caption. Show "No matching pointers" only for empty results.
   - Grid flows inside the page scroll (no nested 320 pt ScrollView). Each cell shows the image, the name and one status glyph (selected ✓, pinned 📌, disabled dimmed, image unavailable ⚠).
   - Click selects. A trailing `…` menu button and the context menu hold **Enabled** (checkmark), **Pin to Toolbar / Unpin**, **Add to Quick controls…** and **Remove Hand…**. The always-visible Enabled checkbox, Select button and Pinned button go away. Keep the per-cell accessibility labels and values.
   - Undo Remove becomes an inline banner above the grid: "Removed Mustard. **Undo**".
4. **Customize sheet** (`PointerCustomization` + `HandGestureSettings`), segmented
   **Look / Sound / Gestures**:
   - Look: Size, Shadow (popup Off / Original / Contact; see Effects).
   - Sound: Tap sound switch, sound popup with an inline ▶︎ preview button.
   - Each customized row gets a small accent dot and a ↺ button, shown only when customized. Remove the "Default"/"Customized" caption on every row. Footer: **Use Defaults for All** · **Done**.
   - Gestures: the existing two slot rows (artwork, Import Artwork…, Restore Starter). For non-hand pointers: "Gestures are available for hands." The "Assign Shortcuts" button goes to Controls › Keyboard › Pointer.
5. **Make your own hand** becomes a sheet launched from **New Hand…** (one entry point;
   the picker popover footer keeps its link to the same sheet). This removes the
   `makingHand` breadcrumb/title swap. `showHandCreator()` opens the sheet.

**Moved out:** none. Every capability stays here or in the sheet.

---

## Effects (renamed from Appearance; absorbs Sound)

**Before (Appearance):** Theme · Pointer preview · Pointer Defaults (Size, Shadow switch,
Shadow style) · Motion (Follow, a status-only row, Tap swing) · Magnification · Toolbar.
**Before (Sound):** App Sound (Mute, Volume) · Pointer Defaults (Tap sound, Sound choice,
Preview, Current pointer status).

**After**

*Subtitle:* "Defaults for every pointer. To change one pointer, use Customize in Pointers."

1. **Preview**: the existing `PointerPreview`, pinned at the top. Its single note line becomes "Lavender toy has its own size. **Customize…**" when overrides exist.
2. **Look**
   - `Size` slider (caption only for non-hands: "Sets Spotlight's radius and the Presentation pointer's thickness").
   - `Shadow` popup **Off / Original / Contact**. This replaces the switch plus the disabled style picker. Off sets `showShadow = false` and keeps `shadowStyle`, so the glossary's independent-style rule holds.
3. **Motion**
   - `Follow` segmented Original / Responsive, with the description as the caption. Delete the separate status-only row (`PresentationSettings.swift:182-187`).
   - `Tap swing` slider (Off … 2×).
   - `Keep the hand visible while interacting` switch (moved from General).
4. **Sound**
   - `Tap sound` switch · sound popup · ▶︎ preview button, all on one row.
   - `Volume` slider with a speaker/mute button at the leading edge (Mute all sounds). Caption only when muted: "All app sounds are muted."
   - Remove the "Current pointer" status row. The preview note covers per-pointer overrides.
5. **Magnification**: Zoom and Lens size. Caption: "Turn on from the toolbar, menu bar or a shortcut." A ⚠ chip appears if Screen Recording is missing, with **Open System Settings…**.

**Moved out:** Theme → General · Toolbar → Controls.

On "Effects": yes. "Appearance" on macOS means light/dark chrome, which is why Theme
ended up here. Everything left on the page happens at the cursor.

---

## Drawing

**Before:** Tools (Selected tool picker) · Practice drawing · Stroke (width, opacity,
smoothing) · Ink (color, Fading, fade delay, trail delay and trail speed appearing conditionally).

**After**

*Subtitle:* "How annotations look and fade. Draw with Interact off."

1. **Practice canvas** first, with the tool chosen inside its header as an icon segmented control (Pen, Rectangle, Arrow, Text, Number, Eraser, Highlighter). The tool stays a live choice demonstrated here; it is not a standalone preference row.
2. **Ink**: `Color` swatches · `Line width` · `Opacity`.
3. **Fading**: segmented **Keep / Fade / Trail** (titles shortened from "Keep until cleared / Whole line / Trail"). Below it, one row: `Fade after` 3 / 6 / 10 s (hidden for Keep).
4. **Advanced** disclosure (collapsed): `Smoothing` (Off / Very light / Light / Medium), and, for Trail only, `Trail delay` and `Trail speed`.

**Moved out:** none. The selected tool is still set from the toolbar, menu bar, Quick
controls, tool keys and Stream Deck.

---

## Controls (renamed from Shortcuts; absorbs Stream Deck and Toolbar)

**Before:** intro paragraph · Quick controls card with two paragraphs · Hand gestures card
· "Pointer and drawing" (13 mixed rows) · "Drawing with Interact off" (nine rows) · error text.

**After**

*Subtitle:* "Shortcuts start unassigned. Click a field and press keys."

0. **Conflict banner** (only when `shortcutConflicts` is non-empty): "⚠ 2 shortcuts are used by another app. **Show**". Show expands and scrolls to the first conflicted row. "Review Shortcut Conflicts…" in the menu lands here.
1. **Quick controls**
   - `Hold to open`: modifier popup (Unassigned / ⌥ / ⌃ / ⇧ / ⌘) with Clear.
   - `Open Quick controls`: shortcut field.
   - Caption: "Hold, move to a choice, release. Needs Accessibility and Pointer On." · **Try It…**
   - The other two paragraphs move into a ⓘ help popover.
2. **Toolbar** (moved from Appearance): `Show toolbar` switch (caption "Appears when the pointer starts or the cursor is near.") · **Reset Position**.
3. **Keyboard**: three groups with consistent names. The Pointer and Presenting groups are expanded; Drawing tools are behind a disclosure. A group with any assigned or conflicted key opens automatically.
   - **Pointer**: Pointer On/Off · Turn Pointer Off (caption "Always turns off.") · Interact On/Off · Next Pointer · Previous Pointer · Tap Sound On/Off · Hold Gesture 1 · Hold Gesture 2
   - **Drawing**: Clear Drawing · Undo Annotation · Redo Annotation · Match Ink to Pointer · ▸ *Tool keys (work with Interact off)*: Pen … Highlighter
   - **Presenting**: Take Screenshot · Capture Region · Magnification On/Off · Toolbar Show/Hide · Open Settings
   - Footer: "Standard editing keys still work in text fields. ⌘, opens Settings."
4. **Stream Deck**: the existing `StreamDeckSettings` card, unchanged.

Gesture slot captions shrink to "Needs a hand with gesture artwork." when unavailable,
with a link to Pointers › Customize › Gestures.

---

## Presets & Backup

**Before:** intro · Saved presets (name field + Save, popup, Apply / Update / Remove,
raw-ID summary) · Portable backup (Export/Import + exclusion paragraph) · Recovery
(Undo + raw folder path) · status text.

**After**

*Subtitle:* "Save pointer, ink and sound setups. Applying one leaves Pointer On, Interact and shortcuts alone."

1. **Presets**: a native list of presets. Each row shows the pointer icon, the name and a summary ("Lavender toy · 6 toolbar pins · 2 disabled"). Show pointer titles, not IDs. Below the list: **+** (Save Current Setup…, a name sheet) and **−**. Double-click or **Apply** applies the selected preset. The context menu has **Update from Current Setup** and **Rename**.
2. **Backup**: **Export…** · **Import…**. A "What's included" disclosure holds the include/exclude text. The import preview sheet stays as is, with IDs shown as titles.
3. **Undo**: once a preset or backup transaction completes, a row reads "Applied Workshop preset. **Undo Last Change**". Replace the raw recovery path with **Show Recovery Folder**.
4. **Reset**: **Reset All Settings…** (destructive style, moved from About; same alert text).

Follow-up outside Settings: there is no preset command in `MenuBarCommands` or
`ControlBridge`, so presets can only be applied from Settings. Add an
**Apply Preset ▸** submenu under More Commands › Presentation. That is what makes
presets worth having during a talk.

---

## About

**After:** app icon, **Look Here Please**, "Version 1.2.0 (20261116015628)", tagline,
"By Austin Presley" in the header (not as a row that looks like a setting), then links:
GitHub, Based on TinyHand, License, Open-source notices. Check for Updates and Reset are
gone (General and Presets & Backup hold them; the menu bar keeps "Check for Updates…").

---

## Capability ledger (nothing dropped)

| Capability | New destination |
| --- | --- |
| Interact switch | Menu bar Interact switch, toolbar, Controls › Interact On/Off, Quick controls, Stream Deck (removed from Settings) |
| Selected drawing tool | Drawing › practice header; toolbar, menu, tool keys |
| Keep hand visible while interacting | Effects › Motion |
| Theme | General › App appearance |
| Toolbar show and reset position | Controls › Toolbar |
| Toolbar pins | Pointers › Favorites › Toolbar |
| Quick controls favorites | Pointers › Favorites › Quick controls › Edit… (PointerBrowser) |
| Enable, pin or remove a pointer, undo remove | Pointers › Library cell `…` menu and context menu; Undo banner |
| Per-pointer overrides, Use Default | Pointers › Customize… sheet (↺ per row, Use Defaults for All) |
| Gesture artwork | Pointers › Customize… › Gestures; menu "Edit Gesture Artwork…" |
| Hand maker | Pointers › New Hand… sheet |
| Pointer defaults (size, shadow, motion, swing, sound) | Effects |
| App volume and master mute | Effects › Sound |
| Magnification zoom and lens | Effects › Magnification |
| Stream Deck install | Controls › Stream Deck |
| Practice | General footer; Controls › Quick controls › Try It… |
| Updates | General › Startup and updates; menu "Check for Updates…" |
| Reset all | Presets & Backup › Reset |

## Prioritized recommendations

- **P1: Restructure navigation** to General / Pointers / Effects / Drawing / Controls /
  Presets & Backup / About. Fold Sound into Effects, move Theme to General, move the
  Toolbar and Stream Deck cards to Controls, move Reset to Presets & Backup. Keep the old
  section IDs as redirects.
- **P1: Shrink Pointers.** Add the current-pointer header and the Customize sheet with
  gestures. Replace the filter UI with one search field and a Show popup. Remove the
  nested scroll and cut each cell to click-to-select plus a `…` menu. Make the hand maker a sheet.
- **P1: Remove live state from Settings** (the Interact switch and the standalone
  Selected tool row).
- **P2: Group Controls › Keyboard** into Pointer / Drawing / Presenting, use consistent
  "X On/Off" names, put tool keys behind a disclosure, and add the conflict banner.
- **P2: Status-first permissions**: chips, a button only when action is needed,
  Accessibility's caption lists Quick controls, and no re-prompt once trusted.
- **P2: One home for updates** with Check Now, last checked and an explicit "not set up
  in this build" state.
- **P2: Replace the interlocked screenshot switches** with the "After capturing" popup.
- **P3: Copy pass.** Cut the paragraph intros to one subtitle per page, move secondary
  explanations into ⓘ popovers, show pointer titles instead of IDs in Presets, and
  collapse the shadow switch and style into one popup.
- **P3: Settings rendering reliability.** Replace the 1 s whole-tree `refresh()` with
  `NSApplication.didBecomeActive` plus a permission check that runs only while General
  or Effects is visible. Observe `Preferences` change notifications for external writes
  (ControlBridge, menu bar, Stream Deck). Cache `PointerConfigurationDocument` in the
  model instead of reloading it inside `body`.
- **Follow-up (menus): Apply Preset ▸** submenu in More Commands.

### Verification for the implementer (local only)

Use `scripts/build-review.sh` and `scripts/run-tests.sh`, then `scripts/snapshot-settings.py`
against a focused test instance for each of the seven pages in light and dark, plus the
Customize and New Hand sheets. Re-check practice shortcut destinations
(`PracticeShortcutDestination`) and the ControlBridge `settings` section routing. Record
the results in `docs/VALIDATION.md`.
