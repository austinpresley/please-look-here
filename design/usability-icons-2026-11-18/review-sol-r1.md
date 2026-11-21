# Usability and icons review, Sol round 1

**Overall: 58/100. Revise before implementation.**

The cursor-first tool row is a sound simplification. Seeing real hands is better than choosing names from a dropdown. But this proposal removes more explanation and capability than it replaces. A first-time user still has to distinguish pointer visibility, using other apps, drawing readiness, and drawing permission. The polished resting states conceal those decisions.

## Scope and evidence

Reviewed `index.html` on `feature/usability-rethink-icons` against the current working-tree sources. Rendered all eight sections at **1100, 728 and 390 CSS pixels in both light and dark**, using the requested local `playwright-core` and Google Chrome executable. Inspected all 48 section screenshots. All six runs reported no page errors. Temporary captures are `/tmp/lhp-sol-r1-{width}-{light|dark}-{1..8}.png`.

Also exercised the HTML tool selection, stars, and fading choices, and measured targets and scaled layouts. These were browser-only interactions. No app launch, native input, smoke script, source edit, build, commit, or hosted CI run was performed. This file is the only repository file created by this review.

Read the requested Swift files and protocol/integration documents, plus the related customization, drawing, sound, shortcut and accessibility implementations. `docs/INTEGRATION.md` explicitly marks some interaction history as superseded; the current Swift and control protocol take precedence here. This is a design review, not evidence of native VoiceOver or keyboard testing.

## Scores by section

Scores are out of 100. The overall score is their unweighted mean.

| Section | Score | Assessment |
| --- | ---: | --- |
| 01 Menu bar | 62 | Faster hand selection and one tool row, but visibility, readiness and sound scope become obscure. |
| 02 Floating toolbar | 58 | Useful contextual grouping; hides history, hides most tools, and moves shared actions between states. |
| 03 Pointers | 45 | Inspector is promising. Shared defaults, independent overrides, favorites mapping and several existing controls are unresolved. |
| 04 Drawing | 58 | Keep/Fade/Trail choices scan well. Width precision and colors disappear; the preview does not demonstrate the promised behavior. |
| 05 Shortcuts | 48 | Visible commands and keycaps help. Suggested bindings are unsafe examples, and much of the command catalog has no shown home. |
| 06 Presets & backup | 54 | Pictures help recognition. Management, persistent recovery and backup boundaries have been stripped out of the proposal. |
| 07 First run | 60 | Better artwork and a focused practice instruction. The welcome does not teach recovery or explain the wheel gesture. |
| 08 Quick controls | 79 | Most restrained change. Keeps labels, positions and recognizable actions; needs explicit cursor semantics and alternate states. |

## P0

None found. This is an unshipped proposal. The issues below block a safe, complete design handoff, but there is no demonstrated catastrophic defect.

## P1 findings

### P1-01 · Pointers · The merge drops existing controls without assigning a destination

The inspector shows size, shadow, sound choice and two gesture pictures. It does not show tap-sound enable/disable, app volume and global mute, Original/Responsive follow, tap swing, or keeping the hand visible during clicks and drags. The library loses shown actions for enable/disable, custom-hand removal and recovery, and gesture artwork import/restore and shortcut assignment. The grid shows only 25 hands, with no shown continuation to the remaining library or Spotlight/Presentation pointers. Laser appears only among favorites.

These are working capabilities in `SettingsPages.swift:57`, `SoundSettings.swift:12`, `PointerCustomization.swift:44`, `HandGestureSettings.swift:9` and `PointerLibrary.swift:117`. A plus button titled "New hand" accounts for creation, not these other operations. General is named but never mocked, so it cannot substantiate their relocation.

**Fix:** Keep the inspector, add a compact selected-pointer action menu for enable/remove, and make gesture thumbnails open artwork controls. Add an app-wide effects disclosure below the inspector for motion and volume. Show the full scrollable catalog, including non-hand pointer types, and a missing/disabled entry. Draw the proposed General page if it receives any of these controls.

### P1-02 · Pointers · "This / All" hides a consequential distinction

Does All edit shared defaults while retaining overrides, or overwrite every pointer? The tooltip says "Every hand", which suggests the latter. The selected hand, title and preview remain present, with no visible inheritance state. A user cannot predict which other pointers will change. "Reset per value" is demonstrated only for size. Shadow enable, shadow style, sound enable and sound choice need independent inheritance too.

Current `PointerCustomization.swift` already has per-value Use Default actions. The before capture has no custom values, so those conditional controls are absent. This proposal is not introducing that capability.

**Fix:** Use a scope control with a hand for This pointer and a defaults icon for Defaults. Keep shared defaults distinct from a separate bulk-copy action. Mark overridden rows with a small reset badge, show the inherited value on hover, and provide a reset for every overridable value. Show one mixed-defaults example and undo for bulk changes.

### P1-03 · Pointers, toolbar, wheel · One favorites list has no capacity or migration rule

The current toolbar supports one to eight pins. The wheel has six fixed directional favorites and preserves unavailable entries in their saved positions. Their orders can differ. The mock shows six favorites plus an add slot and says every star feeds both. It does not say what the seventh star does, how removal affects wheel directions, or how existing differing lists survive. Even its examples disagree: the menu/toolbar start with Lavender, while the settings favorite row starts with Glove.

Evidence: `Preferences.swift:282`, `RadialCatalog.swift:3`, `PointersSettingsPage.swift:30`. The HTML star handler changes a star locally but never updates the favorite row, so the central promise cannot be evaluated interactively.

**Fix:** Use one favorites editor with explicit toolbar and wheel destination badges. Keep eight toolbar positions and six directional wheel assignments visible in that editor. Reordering toolbar favorites must not silently remap learned wheel directions. Show the full state, a seventh favorite, unavailable artwork, and migration of differing existing assignments.

### P1-04 · Menu bar, toolbar, first run · Pointer visibility and drawing readiness have vanished

The power button is a command with no visible On/Off state. A selected pen can therefore look ready while the pointer is off. No after state shows missing Accessibility permission, revoked permission, or pending capture. Those conditions matter: selecting a tool currently changes mode and tool while preserving activation; drawing needs Accessibility, and tool changes can be rejected during capture. `MenuBarControls.swift:204` displays readiness and error feedback; `Toolbar.swift:150` has an Allow Drawing action.

**Fix:** Retain a compact, visibly stateful Pointer switch in the header, using hand artwork to distinguish it from app power. Keep the cursor-first tool row. Add one small status/action slot that becomes the permission repair button or capture progress when needed. Mock Pointer Off, Cursor On, Draw ready, and permission denied. Rejected selection must leave the actual tool visibly selected.

### P1-05 · Shortcuts, first run · The suggested modifier scheme conflicts with VoiceOver and the app

The entire suggested set uses Control-Option, including holding that pair for Quick controls. Control-Option is a default VoiceOver modifier. Adopting this scheme risks collisions for the people who most need predictable keyboard access. The wheel currently accepts a single modifier, Option, Control, Shift or Command, not a two-modifier chord, and starts unassigned. The welcome presents the example chord without the Shortcuts page's caveat.

Evidence: `RadialInput.swift:286`, `docs/control-protocol.md` under Radial quick controls, and [Apple's VoiceOver modifier documentation](https://support.apple.com/guide/voiceover/vo2681/mac). A two-modifier trigger is feasible native work, but it is not a supported current setting.

**Fix:** Remove Control-Option as the recommended set. Make Use fill only unassigned commands after checking system and app conflicts, with a reversible result. Show conflicts inline beside the affected keycaps. The welcome should display the actual assigned trigger or a setup control, and depict hold, move, release rather than bare keycaps.

### P1-06 · Menu bar, toolbar · Switching to Cursor removes the way to clean up existing ink

Clicking Cursor in the HTML hides Undo, Redo and Clear, not just colors. Existing ink is still useful while clicking through a presentation, and mistakes may be noticed after returning to an app. The current popover history is independent of mode; the current toolbar also keeps Undo in its first row. `OverlayController.swift:332` implements history independently of mode.

**Fix:** Keep a stable history group available in Cursor and Draw. Disable it when history is empty. If space is tight, keep Undo visible with a history menu for Redo and Clear. Do not make the presenter enter drawing mode just to remove ink.

### P1-07 · Floating toolbar · Most tools are hidden, and the remaining controls move

Only Cursor, Pen and Highlighter are directly shown. Rectangle, Arrow, Text, Number and Eraser move behind a chevron, whereas the current drawing toolbar exposes them. No state shows how an active Arrow or Text remains visible after the picker closes. The pointer toolbar measures 567px wide and the drawing toolbar 593px; the power button and capture group move 26px to the right. The color subset also loses orange, purple and white without a palette affordance.

**Fix:** Keep Cursor and an always-visible current-tool picker whose face changes to the active tool, with a short familiar tool grid in its popover. Reserve the same width for contextual content so history, capture, sound and visibility retain their positions. Add a palette overflow that exposes all existing colors.

### P1-08 · Drawing · Easier choices should not remove precision or change Trail's meaning

The current width range is 2–20pt in 1pt steps. Four samples, 3/6/10/16, cannot represent existing widths. White ink is absent. Size and opacity lose visible numeric values. Selecting Trail hides the entire timing row, including the only Smoothing and timing button. Existing Trail has pen delay/speed plus whole-mark fading for other annotations. The static sine wave does not explain that difference, and only color and width actually update the HTML preview.

Evidence: `PresentationSettings.swift:19`, `PresentationSettings.swift:37`, and the `#fade` handler at `index.html:885`.

**Fix:** Keep sample widths as quick choices, followed by a small continuous slider/value control for the full range and saved custom value. Restore white. Put advanced settings outside the row that disappears. Show timed preview frames for Keep, whole-line Fade and tail-erasing Trail, including an arrow or text mark in Trail. Retain local practice drawing through a compact preview tool strip.

### P1-09 · Presets & backup · Attractive cards conceal setup changes and remove recovery

There is no shown update-current-preset or remove action. The checkmark does not distinguish a selected card from a setup that still exactly matches the live settings. The before page has persistent Undo Last Change, explicitly retained after restart; the after offers a toast plus an ambiguous recovery-history icon. No persistent undo state is demonstrated. Backup inclusion, exclusions and import review also have no shown replacement. These boundaries prevent someone believing their shortcuts or capture folders were backed up.

Evidence: `PresetsSettings.swift:155`, `PresetsSettings.swift:195`, and `ImportPresentationPreview` in the same file. Applying a preset currently preserves visibility and Interact. The new tool icons must not imply that applying changes mode unless that is explicitly redesigned.

**Fix:** Give each card an ellipsis menu for Update and Remove, and a clear apply control distinct from selection. Retain a persistent recovery row after the toast, including after reopening Settings. Use the backup shield as a disclosure for included/excluded items and preserve the import review sheet. Give Reset All Settings an explicit home.

### P1-10 · Shortcuts · Showing seven rows is not a replacement for the command catalog

Previous pointer, pointer exit, sound, gestures, region capture, magnification, Redo, Match ink, individual tools, toolbar visibility/position and Stream Deck setup are not represented. There is no remaining category disclosure, All commands route, or assigned-only filter. Shortcuts and Presets also lose the shared settings sidebar, unlike Pointers and Drawing.

**Fix:** Place a small Recommended group above the complete searchable command list. Keep the same Settings sidebar on every page. Put less frequent commands in closed groups rather than deleting their destinations. Use one clickable keycap field per command with a clear-assignment action.

### P1-11 · All controls · The target sizes and keyboard model do not meet the brief

At unscaled desktop size the popover swatches are actual **18×18px buttons**, with no larger wrapper. Grid stars have 14×14px targets, and the inspector reset is 26×26px. The stars are SVG click targets inside the pointer-selection button, so keyboard activation selects the pointer but cannot separately star it. Favorite reordering is described only in a hover title. Several swatches have neither a title nor accessible name. Static sliders, switches and keycap spans provide no evidence of value announcements or keyboard editing.

**Fix:** Center 18px artwork in at least about 28pt hit regions, as requested. Make selection and starring separate sibling controls with separate accessibility actions. Add Move Left/Right to the favorite menu. Implement the native version with standard buttons, segmented controls, sliders and shortcut recorders; give every icon-only command a name, state and help. Use arrow-key selection within tool/color groups and visible focus. These are feasible native controls, not a reason to abandon the layout. [Apple's button guidance](https://developer.apple.com/design/human-interface-guidelines/buttons) and [VoiceOver guidance](https://developer.apple.com/design/human-interface-guidelines/voiceover) support familiar actions and meaningful accessible descriptions.

### P1-12 · Review page · Narrow rendering fits boxes by making the work unreadable

There is no horizontal document overflow, but the scale-to-fit approach fails the requested narrow review. At 728px, Drawing is 316px wide with nominal 13px type rendered at roughly **7px**. At 390px, Pointers is a 760px desktop window reduced to 350px, making nominal type roughly **6px**. Toolbar tool targets become roughly **16px**. The 640px stacking breakpoint comes too late. Mobile reviewers cannot judge the icon work at useful size.

**Fix:** Stack comparisons before either settings window would need severe reduction. On phones, show a readable content-only detail plus a clearly identified full-window overview, or provide a full-size scroll/zoom view. Preserve native-size controls in the detailed view. Treat this as a review-document issue, not evidence that the Mac app needs a phone layout.

## P2 findings

### P2-01 · All sections · Several icons have multiple plausible meanings

The following need a better icon, grouping or a small essential label. Tooltips help discovery but do not carry the entire meaning during a live presentation.

| Icon and location | Likely misreading | Concrete fix |
| --- | --- | --- |
| Cursor arrow, tool rows and wheel | Select/move annotations, rather than pass clicks to other apps | Use a cursor-click/app-window treatment consistently; briefly reveal "Use apps" on first use. |
| Power, popover and toolbar | Quit the app or stop all tools, rather than hide the pointer | Use the hand plus a visibility state in the header Pointer control. |
| Rainbow disk, ink rows and preset card | Custom color picker, color wheel, or multicolor ink | Show the current hand thumbnail with a small linked-color badge for Match pointer. |
| Plain purple disk, wheel Color | Current color only, rather than a submenu | Add a palette outline or consistent submenu cue while keeping the current-color center. |
| Grid, popover All pointers | App launcher, layout or view-mode switch; the same grid means All in Settings | Use a small hand-grid icon for the library destination; reserve the plain grid for view/filter controls. |
| Chevron, toolbar More tools | Collapse toolbar or reveal a second row | Attach it to the current-tool button so it visibly forms one picker. |
| Speaker waves, menu/toolbar | System volume or global mute; current app action controls the selected pointer's tap sound | Put a small hand badge on tap sound, show enabled/slashed states, reserve a plain speaker for app-wide volume. |
| Pushpin, Drawing Keep | Pin the toolbar/window on top | Prefer an unfading stroke picture alongside the retained Keep label. |
| Clock, Drawing Fade | Delay before drawing or playback duration | Show a stroke that fades, retain seconds next to it, and animate the preview. |
| Comet/trail, Drawing Trail | Laser pointer, movement speed or pointer trail | Draw a pen stroke with a diminishing tail, matching the preview. |
| Checkerboard, opacity row | Preview background selection, which the identical checkerboard actually does in Pointers | Use a half-filled circle/transparency ramp for opacity; keep checkerboard for backgrounds. |
| Diagonal expand arrows, pointer size | Full screen or expand preview | Use small/large hand endpoints and a percentage value. |
| Overlapping circles, shadow row | Opacity, blending or duplicate | Use a hand casting a small shadow so its subject is clear. |
| Circular reset arrow, inspector | Undo last edit, restart animation, or factory reset | Keep it aligned inside the affected row, show only on overrides, and name the inherited value in help. |
| Wheel spoke icon and tiny favorite badges | Settings, loading spinner, or decoration | Use one consistent radial icon; replace repeated 10px badges with one destination header or a direction map. |
| OK/Shaka pictures, inspector | Choose/show the pose now, rather than import artwork or assign a trigger | Add a small edit badge and reveal distinct artwork/shortcut actions in the thumbnail popover. |
| Play, preset Apply | Preview or animate the hand, as Play does elsewhere | Use an apply/check-in-circle action, reserve Play for previews. |
| History arrow, backup row | Undo, restore immediately, or reset backup | Use a folder-with-clock treatment; open a named recovery list before any restoration. |
| Layers stack, Presets and All scope | Layer order, grouped annotations or an archive | Use a small stack of setup cards for presets, and a distinct defaults treatment for scope. |
| Circled 1, Number tool | Information, first slide or a count badge | Keep the conventional numbered marker, but expose its name and placement preview in the tool picker. |

Pen/highlighter/eraser, rectangle, annotation arrow, text, camera, gear, Undo/Redo, plus and close are sufficiently conventional in their immediate groups. Their targets and accessible names still need work. The wheel's retained text labels are a strength.

### P2-02 · Floating toolbar, wheel · Cursor must be a selection, not an old toggle with a new name

The current wheel Interact slice toggles the mode. A Cursor tool should consistently select app interaction, including when clicked twice. Merely renaming the existing slice would turn drawing back on when someone tries to confirm Cursor. The after only shows Cursor checked, never the drawing state.

**Fix:** Specify an idempotent Cursor action that sends Interact enabled. Show Cursor checked only in that mode, and show the actual selected drawing tool when drawing. Keep the existing mode-toggle shortcut as a separate documented action.

### P2-03 · Drawing navigation · "Drawing" is a poor parent for capture and magnification

The sidebar says Drawing while its camera and magnifier tabs configure independent presentation tools. This is narrower terminology than the current Tools page. No after view shows those tabs' contents or permission states.

**Fix:** Retain Tools as the sidebar name and use compact labeled icon segments inside it. Show one capture destination/permission state and one magnification state. Removing two short tab labels has little payoff in a Settings window.

### P2-04 · First run · Three tiles are not three explanatory pictures

Point and Draw are small icons, while the third tile is an unfamiliar wheel and unexplained keycaps. There is no visual demonstration of clicking an app, holding/moving/releasing, or returning to Cursor when clicks stop reaching the app. Only one of the proposed three practice steps is shown. The preview hand and permanent Nice badge suggest success before a learner does anything.

**Fix:** Make the first tile depict a real button being clicked through, the second depict a stroke, and the third depict the wheel path with hold/release key states. Show one successful app click before drawing, then explicitly practice returning to Cursor. Keep Practice optional and show permission repair only at desktop drawing use. Award completion after the actual action; include replay and skip paths.

### P2-05 · Before/after comparisons · Real captures are useful, but the pairs are not equally complete

| Pair | Fairness check and correction |
| --- | --- |
| Menu bar | The before is a real Arrow/drawing state; the after is Pen. Compare the same pointer, tool, activation and sound state, then include Off/permission variants. Tool selection already turns Interact off today, so describe the improvement as clearer presentation and switch removal. |
| Toolbar | The before shows only Interact On. Current Draw reveals all tools/colors in a second row. Show both current moments, matching the two proposed moments, so the reduced tool access is visible. |
| Pointers | This is two pages plus a sheet, not literally three pages. Shrinking all three current views beside one much larger after exaggerates the improvement. Compare the same editing task at equal scale. Per-value reset already exists when customized. |
| Drawing | The current preview is interactive local practice with sample playback, not just button clutter. The after curve only proves color/width updates. Compare the same practice and fading task, including a custom width and Trail. |
| Shortcuts | Seven closed groups are real. The claim that all are Unassigned is false for Toolbar and Stream Deck; those summarize Shown and Plugin setup. Show an expanded current group against the complete proposed list, with equal command coverage. |
| Presets | The current page already has hand thumbnails and durable undo. The new cards improve scanning; they do not introduce picture recognition or recovery. Show the same saved setup data and recovery lifecycle. |
| First run | The current code already offers local, permission-free practice and a welcome Practice button. The supplied welcome capture does not show that button. Show comparable practice steps and account for this code/capture mismatch. |
| Quick controls | The root arrangement is substantially matched and fair. Retaining labels is appropriate. Add the Draw-selected root and pointer submenu to demonstrate the shared-favorites claim. |

### P2-06 · Visual polish · The settings frame and contrast treatment drift

Shortcuts and Presets are presented as separate titleless windows with no sidebar or page title, while the other pages share a Settings frame. Pointers uses a 176px sidebar; Drawing uses 150px. Several windows leave large blank lower areas while tightly packing the working controls above. Small favorite wheel badges add noise and obscure the hand bases. Dark mode changes the mock controls, but the outer review page remains bright white and "After" retains its dark purple label. The light toast's small purple Undo has weak contrast on its near-black background.

**Fix:** Use one consistent Settings frame, sidebar width, title and content inset. Size the content area to the demonstrated controls or use the spare space for a readable inspector. Replace repeated wheel badges with one group-level destination treatment. Give the document shell its own dark tokens and a readable toast action color. Keep the current generally aligned form rows and restrained accent.

### P2-07 · Prototype consistency · The central promises need a few connected states

Changing a pointer updates its name and picture but leaves the This thumbnail, star state and fixed Lavender wheel examples behind. Starring a tile never adds it to the favorites strip. Scope buttons change selection styling without showing scope-specific values. These are mock limitations, not asserted native bugs, but they prevent validating consistency across the proposed controls.

**Fix:** Connect one representative pointer, star/unstar, scope and mode state across the examples, or present explicit labeled state frames. Do not imply interaction proof where the mock only changes a highlight.

## Native feasibility and HIG fit

A native inspector, contextual floating panel, hand thumbnails, visual presets and a custom radial menu are all reasonable macOS implementations. No fundamental platform impossibility was found. Most 30–32px tool buttons are appropriately sized before scaling, and the existing real hand art integrates well with monochrome command icons.

The remaining native work is substantive: preserve the nonactivating toolbar's input behavior, permission recovery, truthful selection after rejected commands, named icon controls, keyboard alternatives to drag, and the wheel's accessible menu/list representation. `RadialAccessibility.swift` and `QuickControlsList.swift` already provide more than the single image shown by the mock. Retain those capabilities. A timer-based toast must not become the only route to Undo; [Apple's accessibility guidance](https://developer.apple.com/design/human-interface-guidelines/accessibility) specifically cautions about controls that auto-dismiss before people can reach them.

## What works and must be kept

- Cursor as the first member of one tool family. It removes the inverted "turn Interact off to draw" instruction, provided visibility stays separate and mode is truthful.
- Real hand thumbnails for rapid recognition in the popover and library.
- A nearby inspector that avoids opening a customization sheet for every change.
- Keep/Fade/Trail as short, labeled visual choices, supported by a behavior preview.
- Searchable commands with readable keycaps and optional suggestions after conflict checks.
- Picture-led preset cards, with persistent undo and management restored.
- Optional local practice with one task at a time.
- The wheel's stable root positions and short text labels. Do not turn this into an entirely icon-only wheel.
