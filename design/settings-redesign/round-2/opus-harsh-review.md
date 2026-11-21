# Settings redesign v1: harsh review (Opus 5.5, high effort)

This review covers the **first proposal**, not the shipped app. I did not change v1 files or
app code. I did not build the app, run tests or drive the native app.

## What I looked at

- `build-proposal.py`: every page render function, the click and change handlers, and the
  toasts and captions.
- `opus-review.md`, `inventory.json`, `validation.json`, and the light-mode before captures
  for all eight current pages.
- Source used to check the proposal's claims: `PresentationSettings.swift`, `PointerCustomization.swift`,
  `SoundSettings.swift`, `HandGestureSettings.swift`, `MagnificationSettings.swift`,
  `PresetsSettings.swift`, `StreamDeckInstaller.swift`, `HandMakerSettings.swift`,
  `PresentationAction.swift`, `PointerLibrary.swift`, `Preferences.swift` (`InkChoice`) and
  `PointerConfiguration.swift` (`supportsShadow`, `supportsShadowStyle`).
- **Visual checks I actually made.** I copied `preview.html` to `/tmp` with relative image paths,
  served it locally and took headless Chrome screenshots at 720 px width. Views captured:
  - General, Pointers, Drawing and Presets & Backup.
  - Effects, collapsed and with every disclosure open.
  - Effects with every disclosure open, in dark mode.
  - Controls › Keyboard, Quick controls, Toolbar and Stream Deck.
  - Controls › Keyboard in dark mode.
  - About.
  - Customize › Look, Sound and Gestures.
  - New Hand and the tile "···" actions.

  I did **not** check VoiceOver, keyboard traversal in a real browser, long localized labels or
  narrow widths. The T3 in-app preview timed out on both files, so those screenshots come from
  local Chrome only.

## Grading scale

| Criterion | Points |
| --- | ---: |
| Task clarity | 20 |
| Findability | 20 |
| Cognitive load | 15 |
| Scope and interaction correctness | 20 |
| Feedback and accessibility | 15 |
| Native craft | 10 |

A score of 90 is exceptional and 80 is solid. 70 means unfinished, 60 means materially
confusing, and anything under 60 needs rework.

---

## Overall: 66 / 100 (D+)

**v1 is a clear improvement on the current app**, which I'd put around 55 using the same rubric.
Dropping Interact from General is right, and so is the single "After capturing" choice. Moving
Reset and Updates out of About is right. The Customize and New Hand sheets are the right shape.

**v1 is not a finished design.** It does three things in particular that the goals forbid:

1. **It breaks independent overrides in Customize.** One Shadow popup ("Use shared default /
   Off / Original / Contact") stands in for two separate override fields, `shadow` and
   `shadowStyle` (`PointerCustomization.swift:32-47`). The same sheet also uses two different
   reset patterns.
2. **It hides state that the current app shows.**
   - Library tiles lose their Enabled, Pinned, missing-artwork and Ready status.
   - Hold Gesture rows lose their availability caption.
   - Stream Deck loses its version and install status.
   - The Drawing page loses its "Match the pointer" swatch, Replay Sample and Undo.
3. **It moves complexity instead of removing it.**
   - Effects is a bucket of four scopes behind three disclosures.
   - Controls is a broad name with four tabs.
   - Toolbar pinning starts in Pointers, but the result only appears on Controls › Toolbar.

The mock also has prototype-only controls and design notes rendered as if they were app UI,
for example "Preview permission issue", "The implementation will show Restore Default…",
"Shown when the host app is missing." and "Build shown here". Several handlers also contradict
the captions next to them; see "Mock and caption misrepresentations" below.

### Architecture verdict

**Rejected in part.**

**Keep:**
- General as app setup.
- Pointers for choosing, with Customize and New Hand as sheets.
- Drawing.
- Presets & Backup.
- About.

**Reject:**
1. **Effects as built.** It mixes four scopes on one page:
   - Overridable pointer defaults: size, shadow, tap sound and sound choice.
   - Global pointer behavior: follow, tap swing and keeping the hand visible.
   - App output: mute and volume.
   - A separate tool: magnification.

   Its subtitle, "Shared defaults. Customize one pointer in Pointers.", is **false for most of
   the page**. `PointerOverride` holds only size, shadow, shadowStyle, soundEnabled and sound.
2. **The four tabs inside Controls.** They add a layer of navigation in front of content that
   amounts to two rows for Toolbar and one row for Stream Deck.
3. **The deviation that moves favorites to Controls.** It separates the Pin action, which is
   on the Pointers tile menu, from where its result shows, which is on the Controls › Toolbar
   tab. The prior Opus recommendation was right on this point.

**Recommended sidebar (seven pages):**

| Page | Contents |
| --- | --- |
| General | Permissions first, then Startup and updates, then Theme |
| Pointers | Favorites strip, then the library. Customize and New Hand open as sheets |
| Pointer Defaults | Replaces Effects. Look, Sound and Motion, every row visible, no disclosures |
| Tools | Replaces Drawing. Drawing, Magnifier and Screenshots |
| Controls | One scroll, no tabs: conflicts, Toolbar, Quick controls, Keyboard Shortcuts, Stream Deck |
| Presets & Backup | Presets, backup, undo and reset |
| About | Identity, version and credits |

---

## Grades at a glance

| View | Clarity /20 | Find /20 | Load /15 | Scope /20 | Feedback & a11y /15 | Craft /10 | **Score** | Grade |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | :---: |
| General | 15 | 14 | 13 | 15 | 10 | 7 | **74** | C |
| Pointers | 16 | 12 | 12 | 10 | 7 | 6 | **63** | D |
| Effects | 9 | 12 | 10 | 9 | 9 | 7 | **56** | F |
| Drawing | 17 | 16 | 12 | 11 | 9 | 8 | **73** | C |
| Controls (container) | 11 | 11 | 11 | 11 | 8 | 7 | **59** | F |
| Controls › Keyboard | 15 | 12 | 11 | 9 | 8 | 7 | **62** | D |
| Controls › Quick controls | 16 | 15 | 12 | 14 | 10 | 7 | **74** | C |
| Controls › Toolbar | 14 | 12 | 12 | 13 | 9 | 6 | **66** | D |
| Controls › Stream Deck | 15 | 12 | 13 | 12 | 6 | 6 | **64** | D |
| Presets & Backup | 16 | 15 | 12 | 13 | 9 | 7 | **72** | C |
| About | 18 | 16 | 14 | 17 | 10 | 6 | **81** | B− |
| Customize › Look | 14 | 14 | 10 | 7 | 7 | 6 | **58** | F |
| Customize › Sound | 15 | 14 | 11 | 13 | 8 | 6 | **67** | D+ |
| Customize › Gestures | 13 | 11 | 12 | 12 | 8 | 6 | **62** | D |
| New Hand | 14 | 14 | 12 | 10 | 9 | 6 | **65** | D |

The overall score is the mean of the seven top-level pages, with Controls weighted by its four
views. That gives 66.

---

## General: 74 (C)

**What's there, from the 720 px screenshot**

- Subtitle: "Permissions, screenshots and app preferences."
- Groups, top to bottom:
  - Startup and updates: "Open at login", plus an "Updates" row with a **Details…** button and
    "Updates are not set up in this review build."
  - App appearance: Theme, a single row.
  - Screenshots: After capturing, Save folder.
  - Permissions: Accessibility ✓ Allowed and Screen Recording ✓ Allowed, with no buttons.
- Footer links: "Practice the Controls… · Preview permission issue".

**The 3 most costly failures**

1. **Permissions are last.** This is the one group that decides whether drawing, tool keys,
   Quick controls, screenshots and the magnifier work. Someone who hasn't granted Accessibility
   sees three other groups first. The prior review put Permissions first, and v1 reversed that
   without saying why.
2. **Updates are hidden behind "Details…".** The everyday controls (check automatically, Check
   Now, last checked) live in a sheet, and that sheet is a reviewer device showing both build
   states at once. This buries a common action, which goal 3 rules out.
3. **Missing and fake states.**
   - There is no **"Not requested yet"** state for Screen Recording. The source shows
     "Requested when you first take a screenshot…" for this case.
   - "Preview permission issue" is a prototype toggle styled like an app link.
   - The Accessibility denied state appears only in a modal. The real UI shows it inline.

**Replacement layout**

Everything is visible by default. Nothing is disclosed.

1. **Permissions**
   - Accessibility: status chip, plus **Open System Settings…** only when not allowed.
     Caption: "Needed to draw, use tool keys and Quick controls."
   - Screen Recording: Allowed / Not allowed / Not requested yet.
     Caption: "Needed for screenshots and the magnifier."
2. **Startup and updates**
   - Open at login.
   - Check for updates automatically, with **Check Now** and the caption "Last checked today at 9:41".
   - In builds with no update feed, keep one disabled row: "Updates aren't set up in this build."
3. **Appearance**
   - Theme as a segmented control (System / Light / Dark). It has three options, as it does
     today. Caption: "Settings, toolbar and menus."
4. **Screenshots**
   - This group moves to Tools if you adopt the architecture above. Otherwise keep it here.
5. Footer: "New to Look Here Please? **Practice the Controls…**"

**Copy**

- Subtitle: "Permissions, startup and updates." Drop "app preferences".
- Remove "Preview permission issue" from the mock.

**What could be lost**

- `captureSaves` and `captureCopies` must not both turn off. The popup prevents that state; keep it so.
- The folder must be kept when "Copy to clipboard" hides the row.
- Keep the menu route "Allow Drawing…" → General.
- Don't call `AXIsProcessTrustedWithOptions(prompt:)` once trust is granted.

**Fix:** Reorder so Permissions come first, show updates inline, add the "Not requested yet"
state, and delete the reviewer link.

---

## Pointers: 63 (D)

**What's there**

- Header: a 64 pt image, "Current pointer / Lavender toy / Uses shared defaults", and **Customize…**.
- A search field and a **Filter** button. Filter opens an inline checkbox strip, not a menu.
- A three-column grid of tiles. Each tile has an image, a name, a ✓ only when selected, and "···".
- Below the grid: "Edit Favorites…", **New Hand…**, and a caption.
- "···" opens a **modal sheet**, "Pointer actions", containing:
  - An Enabled switch that is always on.
  - A stateless **Pin / Unpin** button.
  - **Choose Slot…**

**The 3 most costly failures**

1. **Tiles hide the state the filters depend on.** The Filter offers Enabled, Pinned and
   Custom, but no tile shows whether it is enabled, pinned, custom or missing artwork. The
   current tiles show a "Selected/Ready" status line, an Enabled checkbox and a
   "Pinned/Not pinned" button (`PointerLibrary.swift:161-180`).

   The inventory promises "Selection, enabled state, missing artwork, pin status → Library
   tile". The tile shows only selection. The source notes that "Pinned pointers can be
   disabled", so these are independent states, and someone needs to see both.
2. **Opening actions changes the live pointer.** The handler for `data-pointer-menu` sets
   `selectedPointer` before opening the sheet. Checking Robot's actions makes Robot your
   desktop pointer. Goal 6 is about not mutating live state by accident, and this does it.
   "Pin / Unpin" also has no state, and pinning changes nothing visible on this page. The
   result only shows on Controls › Toolbar.
3. **Common actions sit under the whole grid.** The real library has 39 pointers (the before
   capture says "Showing 39 of 39"). At three per row that is 13 rows, roughly 1,300 pt, before
   anyone reaches **New Hand…** or **Edit Favorites…**. The mock shows 9 tiles, which hides
   this problem.

**Replacement layout**

Visible by default:

1. **Current pointer** header:
   - A 72 pt sample and the name.
   - A **Customized** chip, or "Uses Pointer Defaults", computed from the actual override.
   - **Customize…**
2. **Favorites**, two rows with the same layout:
   - `Toolbar`: six reorderable slots and +.
   - `Quick controls`: six slots in their real radial order, with **Edit…**.
   - Caption on one line: "Toolbar and Quick controls keep separate lists."
3. **Library toolbar** on one line: Search, **Show ▾** (a pull-down menu with checkable
   Enabled / Pinned / Custom items that can be combined), and **New Hand…**.
4. **Grid**:
   - Each tile shows its image and name, plus status glyphs: ✓ selected, 📌 pinned, dimmed
     with "Off" when disabled, ⚠ when artwork is missing, and a "Custom" badge.
   - The "···" button opens a **menu**, not a sheet, and does not change selection. Menu
     items: Use This Pointer, ✓ Enabled, Pin to Toolbar / Unpin from Toolbar (stateful),
     Add to Quick Controls ▸ (slot submenu), Customize…, and Remove Hand… for custom hands only.
   - The context menu has the same items.
5. **Banners:**
   - Undo after removing a hand: "Removed Mustard. **Undo**". It stays until dismissed.
   - When filters hide the current pointer: "Lavender toy is hidden by filters. **Show All**"

Nothing on this page is disclosed.

**Copy**

- Subtitle: "Choose your pointer. Defaults for every pointer are in Pointer Defaults."
- Delete the footer caption "Select a tile to use it. Actions include…". The tiles should make
  this obvious.
- Rename "Clear filters" to "Show All". It currently clears the search too
  (`activeFilters.clear(); pointerQuery=''`).

**What could be lost**

- Combined filters.
- The "current pointer hidden by filters" note.
- Undo Remove, its persistence, and recovery when artwork is missing.
- Per-tile accessibility labels and values (enabled, pinned).
- The separate PointerBrowser chooser.
- Pin and Enabled must stay independent.

**Fix:** Put state back on the tiles, make "···" a menu with no side effects, move the
favorite strips back above the library, and put New Hand next to search.

---

## Effects: 56 (F, rework)

**What's there** (collapsed and expanded screenshots, light and dark)

- "Shared defaults preview": the pointer artwork at 96 pt, with three links underneath —
  Preview Tap, Preview Motion and "Customize selected pointer…".
- Look: Default size, and a Shadow popup.
- Motion: Follow (a popup), plus a "Motion options" disclosure whose summary reads "Tap swing ·
  Visibility" and which holds Tap swing and Keep hand visible.
- Sound: Mute all sounds, visible, plus a "Sound settings" disclosure holding App volume,
  Default tap sound, Sound and Preview.
- Magnification: a separate group with **no section heading**, collapsed, summary "2× · 240 pt".

**The 3 most costly failures**

1. **The page says one scope but holds four.**
   - The subtitle says "Shared defaults. Customize one pointer in Pointers."
   - Only Size, Shadow, Tap sound and Sound can be overridden per pointer.
   - Follow, Tap swing, Keep visible, Mute, Volume and Magnification are global. No pointer
     can customize them.

   This copy makes people look in Customize for controls that don't exist there. It is the
   miscellaneous bucket you were worried about, and your concern was justified.
2. **The disclosures put the wrong things on top.**
   - The everyday pointer default, **Default tap sound on/off**, is hidden.
   - A global kill switch, **Mute all sounds**, is visible.
   - Tap sounds are the only sounds the app plays (`TapSound.swift`). People therefore face
     three on/off layers (master mute, default tap sound, per-pointer tap sound), and the one
     they most likely mean is collapsed.
   - Disclosure summaries list names ("Tap swing · Visibility", "Tap sound · App volume") where
     they should list values. Magnification does list values, so even the summaries are inconsistent.
3. **The preview's scope can mislead.**
   - The "Shared defaults preview" draws the **selected** pointer, and the size slider scales
     it (`style.scale = value/13`).
   - If Lavender toy overrides Size, moving Default size grows the preview, but Lavender won't
     change on the desktop. The mock shows the defaults applied to a pointer that ignores them.
   - "Customize selected pointer…" sits in the preview's toolbar on the defaults page, right
     next to Preview Tap. That is the scope confusion goal 2 forbids.

**Lost copy that mattered**

- **Size** caption: "Also sets Spotlight's circle size and Presentation pointer's thickness."
- **Follow** is now a popup with no description of what Original and Responsive do.
- The Shadow style caption describing Contact.
- Tap swing: "Reduce Motion turns the swing off."
- Lens: "stays on the current display and marks the exact cursor position."

**Replacement layout: "Pointer Defaults"**

Every row is visible; there are no disclosures. It fits in about 820 pt.

1. **Preview**
   - The sample shows Pointer Defaults applied to the current pointer.
   - When that pointer has overrides, add one line under it: "Lavender toy overrides Size, so
     this preview uses its own size. **Customize Lavender toy…**"
   - The background control is a segmented control with Preview Tap and Preview Motion buttons.
2. **Look**
   - Footer: "Each pointer can override these in Pointers › Customize."
   - Size, with the caption "Also sets Spotlight's radius and the Presentation pointer's thickness."
   - Shadow: Off / Original / Contact. Off keeps the last style.
3. **Sound**
   - Footer: "Tap sound and sound can be overridden per pointer. Volume applies to all sounds."
   - Tap sound switch, sound popup and ▶︎, on one row.
   - Volume: a slider with a leading speaker button that toggles **Mute**. When muted, the
     caption reads "All app sounds are muted." and ▶︎ is disabled with that reason.
4. **Motion**
   - Footer: "Applies to every pointer."
   - Follow: segmented Original / Responsive, with a one-line caption that changes with the choice.
   - Tap swing: Off…2×. Caption only when Reduce Motion is on.
   - Keep the hand visible while interacting.

Magnification moves to **Tools › Magnifier**.

**Copy**

- Page title "Pointer Defaults". This term is already in the glossary and in `SoundSettings.swift`.
- Subtitle: "Used by every pointer unless you customize it."

**What could be lost**

- Turning Shadow off must keep `shadowStyle`.
- Preview must respect mute and volume and must not enable tap sound.
- The `.appearance` and `.sound` section aliases must route correctly. Sound should scroll to the Sound group.
- Selecting a sound saves it.

**Fix:** Split the page by scope, remove all three disclosures, move the magnifier out, and
make the preview say when the current pointer differs from the defaults.

---

## Drawing: 73 (C)

**What's there**

- "Practice canvas" with a Clear link and a seven-item text tool strip.
- A canvas showing "Pen sample · Drag to try".
- Ink: eight colour swatches, a **Match ink to pointer** switch, Line width and Opacity.
- Fading: a Behavior popup (Keep / Fade / Trail) and Fade after.
- "Advanced" disclosure, summary "Smoothing".
- Footer: "Practice stays in this canvas. Desktop tool controls remain in the toolbar, menu and Quick controls."

**The 3 most costly failures**

1. **The match switch contradicts the swatches.** "Match the pointer" is one of the nine
   values of `InkChoice` (`Preferences.swift:18`), and the current UI draws it as the rainbow
   swatch. v1 removes that swatch and adds a separate switch. The result is impossible
   combinations, such as Match on with Purple selected.

   The "Match Ink to Pointer" shortcut sets `inkChoice = .match` (`AppDelegate.swift:176`),
   so the shortcut and the switch would describe the same value in two different ways.
2. **Practice functions are gone.** The current practice area has an Interact/Draw local mode,
   **Replay Sample**, and **Undo** (`DrawingPreview.swift:20-21`, `DrawingPractice.swift:36`).
   Replay Sample matters most. Its accessibility help says it previews settings *without
   drawing*, which is how keyboard and VoiceOver users see Fade and Trail in action. v1 keeps only Clear.
3. **Trail lost its explanation.**
   - The source caption is "The start of a pen stroke erases as you draw. Other annotations
     fade as a whole." v1 drops it.
   - It keeps the label "Other annotations fade after", which now has nothing to refer to.
   - "Advanced" is the vague label that goal 3 warns about.

**Replacement layout**

Visible by default:

1. **Practice**
   - A tool strip using icons with text labels, as an icon segmented control.
   - **Replay Sample**, **Undo** and **Clear** in the header.
   - The canvas. Its caption reflects the current fade, e.g. "Whole line fades after 6 seconds."
2. **Ink**
   - Color: nine swatches, rainbow "Match pointer" first, each with a 24 pt hit target.
   - Line width and Opacity.
3. **Fading**
   - Segmented Keep / Fade / Trail. A one-line caption for Trail: "The start of a pen line
     erases as you draw."
   - Fade after.

Disclosed: **"Smoothing and trail timing"** with Smoothing, plus Trail delay and Trail speed
when Trail is selected. The summary shows values, e.g. "Light · 1.0 s · 200 pt/s".

**Copy**

- Keep the subtitle.
- Rename "Fade after" to "Other marks fade after" when Trail is selected.
- Delete the "Match ink to pointer" switch.

**What could be lost**

- The practice canvas must stay local. Selecting a practice tool must never write
  `Preferences.drawingTool`.
- Fade delay must keep its 0.5 s floor.
- Hidden trail values must be kept while Fade or Keep is selected.

**Fix:** Bring back the Match swatch, Replay Sample and Undo, and rename Advanced.

---

## Controls container: 59 (F)

**What's there**

- Subtitle: "Choose how to reach your presentation tools."
- A four-segment bar: Keyboard / Quick controls / Toolbar / Stream Deck.

**The 3 most costly failures**

1. **The name is vague and there is a navigation layer before any content.**
   - People looking for "Shortcuts" or "Hide the toolbar" won't predict "Controls", then a tab.
   - Toolbar (two rows) and Stream Deck (one row) don't need their own views.
   - This is the nested navigation that goal 3 rules out.
2. **The subtitle doesn't say what's here.** "Presentation tools" is not a term the app uses.
3. **Tabs separate related information.** The Hold Gesture keys are under Keyboard, and Quick
   controls favorites are under another tab. There is no overview of which controls are set up.

**Replacement layout**

One scroll, no tabs. Everything is visible by default except two keyboard groups.

0. **Conflict banner**, only when there are conflicts: "⚠ 2 shortcuts conflict with other
   apps. **Show First**".
1. **Toolbar**: Show toolbar, then Position with **Reset Position**. Two rows.
2. **Quick controls**: Hold to open, then Open Quick controls, then the caption and
   **Try It…**. Then the line "Favorites: **Edit in Pointers…**".
3. **Keyboard Shortcuts**: search, then groups.
4. **Stream Deck**: one card.

Subtitle: "Toolbar, Quick controls, keyboard shortcuts and Stream Deck."

**What could be lost**

- `showShortcut(_:)`, `ControlBridge` section routing, practice destinations
  (`PracticeShortcutDestination`) and "Review Shortcut Conflicts…" must still scroll to and
  highlight the matching row. With tabs they also have to switch tab first, which is one more
  thing to break.

### Controls › Keyboard: 62 (D)

**What's there**

- Search, a scope caption, and four disclosure groups. Only **Pointer** is open; Drawing,
  Presenting and Drawing tool keys are collapsed. Summaries show counts like "8 commands".
- Each row has a "Record shortcut" button and **no Clear button**.

**Failures**

1. **The recorder rejects plain keys for tool keys.** It shows "Add Control, Option or Command
   for a global command." for every row. The source passes `allowsPlainKeys: action.tool != nil`,
   because single-key tools are the reason tool keys exist.
2. **Clear and conflicts are not demonstrated.** Clearing exists only as a toast hint
   ("Delete clears"). `conflicts` is never set to `true`, so the conflict banner never appears.
   When it does render, it sits below the search field and the caption, with no Show action.
   Goal 4 asks for conflict handling to be preserved, and nothing here shows it.
3. **Groups and rows hide useful status.**
   - Presenting (Screenshot, Region, Magnification, Toolbar) is collapsed by default.
   - Summaries count commands instead of saying "2 of 5 assigned · ⚠ 1 conflict".
   - Hold Gesture rows lost their availability caption: "Choose a hand with available artwork…".

**Replacement layout**

Visible by default:
- Search, then the line "Shortcuts start unassigned. Click a field, then press keys."
- **Pointer** and **Presenting** groups, open.
- **Drawing**, open when anything in it is assigned.

Disclosed: "Tool keys (Interact off)", 7 rows, with the caption "Single keys work here. They
pause while you type."

Every assigned field gets a trailing ⊗ Clear button with an accessibility label. Conflicted
fields show ⚠ and the name of the app they conflict with.

Group summaries read like "Pointer · 3 of 8 set" or "Presenting · ⚠ 1 conflict". A group with a
conflict opens automatically.

**Copy**

- Rename **Capture Region…** to keep its ellipsis. It asks for more input.
- "Tap Sound On/Off" is fine. Check what it toggles, `overlay.soundOn`, against the Sound
  settings, and say in its caption whether it overrides mute.

### Controls › Quick controls: 74 (C)

**What works:** Hold to open with Clear, then Open Quick controls, a one-line caption, and six
favorite slots with **Practice…** and "How it works". This is the best of the four views.

**Failures**

1. **The slot directions are unverified.** The slots read N/NE/E/SE/SW/W. I couldn't find that
   layout in the source, and `RadialCatalog.swift:68` says positions are deliberately never
   collapsed. Use the real order, and show its shape as a small radial diagram, not a row.
2. **The slots look exactly like toolbar favorites.** Only a caption tells the two lists apart.
3. **The chooser is too limited.** It offers only the first six hands, with no search. The real
   editor (PointerBrowser) searches all 39.

**Fix:** Keep the trigger here. Put the favorites with Pointers › Favorites, as a small radial
diagram, and link to them.

### Controls › Toolbar: 66 (D)

**Failures**

1. Pinning happens in Pointers but order and Unpin are here. The pin flow is split across two pages.
2. Tapping a slot opens a modal sheet with Move Left / Move Right / Unpin buttons. That should
   be a context menu plus drag.
3. **Reset Favorites** has no confirmation and no undo.

**Fix:** Move the strip to Pointers › Favorites. Keep Show toolbar and Reset Position under
Controls › Toolbar.

### Controls › Stream Deck: 64 (D)

**Failures**

1. **A design note is in the UI.** The "Download…" row is always shown, captioned "Shown when
   the host app is missing." The source shows the link only when `installer.needsHost` is true.
2. **Version and status are gone.**
   - The bundled plugin version is gone ("Bundled plugin 1.1.0.0").
   - The `installer.message` status area is gone.
   - The missing and corrupt installer errors (`StreamDeckInstaller.swift:21-22`) have no place.
3. **"Opening Stream Deck…" has no busy state.**

**Fix:** Use one card. The title is "Bundled plugin 1.1.0.0". Caption: "Requires Stream Deck
6.5 or later." Then **Install Plugin…** and, only when the host app is missing, **Download
Stream Deck…**. The status line goes below.

---

## Presets & Backup: 72 (C)

**What's there**

- A list of two presets. Each row has a thumbnail, the name, "Lavender toy · 6 toolbar
  favorites" and **Apply**.
- **Save Current Setup…** and "Preset Actions…" under the list.
- A rule caption.
- Backup: Export… and Import…, plus a "What is included" disclosure.
- Recovery: Undo Last Change (always enabled) and Show Folder.
- "Reset All Settings…" as a text link.

**The 3 most costly failures**

1. **Undo is always enabled.** "Undo Last Change" shows even when there's nothing to undo, and
   it doesn't name the transaction. The source shows `recovery.title` only when a recovery
   exists. Apply only shows a toast.
2. **"Preset Actions…" is vague and modal.** It opens a sheet with Update and Remove. Remove
   has no confirmation, and its toast claims "Undo Last Change restores it". I couldn't
   confirm from the source that removing a preset creates a recovery receipt, so this caption
   may be false.
3. **The summary drops information.** It no longer shows the disabled-pointer count, which
   the source shows, or the missing-pointer fallback note. The Import sheet's footnote
   describes the review it ought to show ("Show every changed setting…").

**Replacement layout**

Visible by default:

1. **Presets list**
   - Rows: name and "Lavender toy · 6 toolbar favorites · 2 pointers off".
   - Select a row to show **Apply**, **Update from Current Setup** and **Remove…** inline. The
     context menu has the same items, plus Rename.
   - Below the list: **+** (Save Current Setup…) and **−**.
2. **Undo banner**, only when a recovery exists: "Applied Workshop. **Undo**". After a restart:
   "Last change: Applied Workshop (restored after restart). **Undo**"
3. **Backup**: Export… and Import…. Caption: "Doesn't include shortcuts, startup, screenshot
   folders or display positions."
4. **Reset All Settings…**: a destructive button in its own group, with an alert that offers
   **Export Backup First**.

Disclosed: "Recovery folder", with **Show in Finder**.

**Copy**

- The rule caption must include "startup", as the source does.
- Show pointer titles, never IDs, both in rows and in the Import review.

**What could be lost**

- Import preview and refusing to apply on conflict.
- `canApply` must keep disabling Import Backup.
- The busy state.
- Recovery must persist across restarts.

**Fix:** Show undo only when it exists, put row actions inline, and confirm before removing.

---

## About: 81 (B−)

**What's there:** a hand image (not the app icon), "Version 1.2.0 · Build shown here", the
tagline, "By Austin Presley", four rows that each have an **Open…** button, and "Updates are
in General".

**Failures**

1. "Build shown here" is placeholder text left in the UI.
2. Four identical **Open…** buttons replace the native link rows with ↗. The ellipsis is wrong:
   opening a URL asks for no more input.
3. The header shows the hand artwork instead of the app icon. "Updates are in General" sends
   people to another page from the place many Mac users expect "Check for Updates".

**Replacement**

- Header: app icon, name, "Version 1.2.0 (20261116015628)", the tagline, then "By Austin Presley".
- Four link rows with a trailing ↗. Open-source notices opens a local file, so it can say "Show".
- No updates link. The menu bar and the app menu already have Check for Updates.

---

## Customize sheet

The sheet's structure is right. Each tab's controls are not.

### Customize › Look: 58 (F)

**What's there**

- Subtitle: "Only Lavender toy. Other pointers keep their own settings."
- Look / Sound / Gestures tabs.
- Hand size slider with "Uses shared default until changed." and a hidden Restore Default.
- **Shadow popup**: "Use shared default / Off / Original / Contact".
- The note "The implementation will show Restore Default only for changed values…"
- Footer: Use Defaults for All, Done.

**Failures**

1. **The popup merges two independent overrides.** `PointerOverride.shadow` and `.shadowStyle`
   are separate fields with separate Use Default buttons. One popup can't express "always show
   a shadow, but follow the default style" or "use Contact whenever the default turns shadow on".

   It also ignores the per-pointer rules: Laser and Spotlight have no shadow, and the
   Presentation pointer has a shadow but no style (`PointerConfiguration.swift:40-41`).
2. **The sheet uses two reset patterns.**
   - Size uses a slider plus Restore Default.
   - Shadow and Sound put "Use shared default" inside a popup, which also hides the effective
     value: you can't see what the default *is*.
3. **Status and safety are missing.**
   - The header always says "Uses shared defaults".
   - "Use Defaults for All" has no undo or confirmation.
   - The source's error row is gone: "Unable to save pointer settings… Restore a valid pointer
     settings export".
   - A design note is rendered in the sheet.

**Replacement**

All of this is visible by default; there are no tabs for Look and Sound. Use one pattern for
every field: the control shows the **effective** value. A small "Custom" tag and a ↺ button
appear only when the field has an override. ↺ clears that field alone.

| Field | Control | Notes |
| --- | --- | --- |
| Size | Slider | Uses `policy.sizeLabel` |
| Shadow | On/Off switch | Only when `supportsShadow` |
| Shadow style | Original / Contact popup | Only when `supportsShadowStyle`. Disabled with "Shadow is off" when off |
| Tap sound | On/Off switch | |
| Sound | Popup and ▶︎ | |

- Header: "Lavender toy: 2 custom settings" or "Lavender toy uses Pointer Defaults".
- Footer: **Reset All to Defaults** (with undo through a toast) and **Done**.

### Customize › Sound: 67 (D+)

**What works:** Tap sound and Sound choice are separate popups, so they stay independent. The
preview caption is honest.

**Failures**

- "Use shared default" hides the value actually in effect.
- The source's status line ("On at 100%", "Muted") is gone.
- There are two override patterns (see Look).

**Fix:** Merge Look and Sound into one section using the single pattern above. That removes a tab.

### Customize › Gestures: 62 (D)

**Failures**

1. **The thumbnails are wrong.** Both gesture slots show the base hand, not the OK and Shaka
   poses. The screenshot misrepresents the feature.
2. **States are missing or always on.**
   - **Restore Starter** is always visible. The source shows it only when the artwork is custom.
   - There's no state for pointers that aren't hands ("Gestures work with hands…").
   - There's no `gestureMessage` area for import errors.
3. **The footer is ambiguous.** On this tab, the sheet-wide **Use Defaults for All** button
   suggests it affects gestures. The toast says it doesn't.

Gesture artwork is also three levels deep: Pointers › Customize › Gestures.

**Fix:** Make Gestures the second section of the sheet, below the overrides, with real pose
thumbnails and conditional Restore. Keep "Assign Shortcuts…" pointing to Controls › Keyboard ›
Pointer. Make the menu item "Edit Gesture Artwork…" open the sheet scrolled to Gestures.

Customize's tabs then go away: one sheet with an Overrides section and a Gestures section.

### New Hand: 65 (D)

**What's there**

- Subtitle: "Add a transparent PNG, or make an image first."
- A drop zone with **Choose Image…**, a Name field, and a "Make an image first" disclosure.
- Footer: **Preview Image** and **Done**.

**Failures**

1. **The footer actions don't fit a creation sheet.** **Done** is ambiguous: does it save or
   discard? The commit action, **Add Hand**, appears only in a second sheet that *replaces*
   this one. In the mock, the typed name is lost when that happens.
2. **The common path is collapsed.** Most people don't have a transparent PNG of the back of a
   hand, so making one is the common path. Putting it in a collapsed disclosure that opens
   below the Name field reverses the current three-step flow without stating why.
3. **The flow drops important feedback.**
   - "Add Hand saves and selects it" from the source is gone. It is a live pointer change, and
     the sheet must say so.
   - The palm-versus-back check is gone.
   - Validation errors appear in a nested sheet instead of inline.

**Replacement**

One sheet, steps visible by default:

1. **Image well**: drop or **Choose Image…**. After a file is chosen it shows an inline preview
   and validation result, e.g. "✓ Transparent edges" or "⚠ This looks like a palm".
   - A secondary link: "No image? **Make one with ChatGPT…**". It expands steps 1 and 2 inline:
     Describe, **Copy Prompt & Open ChatGPT**, and **Copy Prompt**.
2. **Name**.

Footer: **Cancel** and **Add Hand** (the default button, disabled until valid). Caption: "Adds
the hand and makes it your pointer."

---

## Mock and caption misrepresentations

These need fixing before round 2 is judged.

| # | Location | Shows or claims | Actually |
| --- | --- | --- | --- |
| 1 | Pointers "···" | An actions menu | Opens a modal sheet **and selects the pointer** |
| 2 | Pointers caption | "Actions include enable, pin…" | Pin / Unpin has no state; Enabled is always on |
| 3 | Effects subtitle | "Shared defaults" | Most rows aren't defaults and can't be customized |
| 4 | Effects preview | Previews shared defaults on the selected pointer | Ignores that pointer's overrides |
| 5 | Keyboard recorder | Requires a modifier everywhere | Tool keys allow plain keys |
| 6 | Keyboard | Conflict summary and open conflicted groups | `conflicts` is never `true`, so neither ever appears |
| 7 | Customize | "Restore Default only beside changed values" | Only Size does this; the rest are popups |
| 8 | Gestures | Pose thumbnails | Shows the base hand twice; Restore is always visible |
| 9 | Stream Deck | Download row | A design note shown as UI ("Shown when the host app is missing.") |
| 10 | General | "Preview permission issue" and the Updates sheet | Reviewer devices styled as app controls |
| 11 | About | "Build shown here" | Placeholder text |
| 12 | Presets | Remove toast says Undo restores it | Not confirmed in the source |
| 13 | Drawing | Match ink as a switch | It's one value of the swatch choice |

---

## Cross-cutting accessibility and native craft

- **Hit targets.** These are below a comfortable 24 pt pointer target:
  - Swatches are 17 px.
  - "···" is about 16 px tall.
  - The text-link buttons (Clear, Reset Favorites, Preview Tap) have no padding.

  Native macOS controls are larger: the current swatches are 20 pt plus padding.
- **Tile state in VoiceOver.** Tile buttons announce "Select X" and pressed. Pinned, enabled
  and missing artwork aren't announced. Restore those accessibility values.
- **Segmented views.** The subtabs use `aria-pressed` buttons. Natively they'd be a segmented
  `Picker`, and the arrow-key behavior differs. This doesn't matter if you remove the tabs as recommended.
- **Scroll containers.** No page has a nested scroll; the grid scrolls inside the page. In the
  document, `.app-main` has a fixed 620 px internal scroll, which is a mock artifact. The native
  window should scroll its detail pane once.
- **Dark mode.** Checked on Effects and Keyboard. Text and controls are readable. The preview
  well stays light by design when the Light background is chosen.
- **Sidebar.** "Presets & Backup" wraps onto two lines in a 154 px sidebar. Give it at least
  170 pt, or use the label "Presets".

## Highest-impact changes, in order

1. **Fix the override model in Customize.** Show the effective value in every control, with ↺
   only when a field is custom. Keep Shadow and Shadow style as separate fields and respect
   the per-pointer rules. Merge Look and Sound into one section and put Gestures beneath. No tabs.
2. **Replace Effects with Pointer Defaults.** No disclosures. Each group gets a footer that
   states its scope. Tap sound and Volume/Mute stay visible. Give the preview an override
   note. Move Magnification to Tools.
3. **Put state back in Pointers.**
   - Tile glyphs for pinned, off, missing and custom.
   - "···" becomes a menu with no side effects.
   - The favorites strips (Toolbar and Quick controls) go above the library.
   - New Hand goes next to search.
   - Add the Undo banner and the hidden-selection banner.
4. **Flatten Controls into one scroll.** Order: conflict banner, Toolbar, Quick controls,
   Keyboard Shortcuts, Stream Deck. In Keyboard:
   - Each assigned field gets a Clear button.
   - Tool keys accept plain keys.
   - Group summaries say "N of M set" and show conflicts.
   - Pointer and Presenting are open by default.
   - Restore the gesture availability captions.
5. **General:** Permissions first, with a "Not requested yet" state. Updates inline with Check
   Now and last checked, and an explicit row for builds without updates.
6. **Drawing (as Tools › Drawing):** bring back the Match swatch, Replay Sample and Undo, the
   Trail caption, and rename Advanced.
7. **Presets:** show Undo only when a recovery exists, put row actions inline, confirm Remove,
   and restore the disabled-pointer count.
8. **Clean the mock.** Remove every design note and reviewer control from app surfaces, and
   make each handler match its caption (see the misrepresentations table).
9. **New Hand:** footer is Cancel and Add Hand (the default button). Show preview and
   validation inline. State that adding a hand also selects it.
10. **About:** use native link rows and the real icon and build number, and remove the updates link.

Where the prior Opus review and these goals conflict, I sided with the goals:

- Favorites go back to Pointers, overriding the v1 deviation, because the Pin action needs a
  visible result on the same page.
- Effects' disclosures are removed. A short page that hides its everyday controls doesn't meet
  goal 3. Splitting by scope keeps the page short without hiding anything.
