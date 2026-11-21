# Usability and icons review, Sol round 2

**Overall: 74/100. Verdict: revise.**

The revision fixes several substantial problems. The hand switch separates visibility from tool selection, the toolbar holds its position, stars update favorites, and Settings has a consistent sidebar. The proposal is easier to scan than round 1. It is still incomplete where mistakes have consequences: inheritance, the full pointer library, Trail behavior, shortcut changes and recovery. Several responses describe controls that are only named in tooltips or closed disclosures.

## Scope and evidence

Read `review-sol-r1.md` first. Reviewed the revised `index.html` on `feature/usability-rethink-icons`, compared all eight sections with `r1/index-r1.html`, and checked relevant current Swift implementations.

Rendered the revision with the requested local `playwright-core`, Google Chrome executable and `/tmp/lhp-tools/parts.cjs` at **1100, 728 and 390 CSS pixels in light and dark**. Inspected all 48 section captures. All six capture runs reported zero page/console errors. Captures are `/tmp/lhp-sol-r2-{width}-{light|dark}-{1..8}.png`.

The archived round 1 HTML has broken relative asset paths when opened in its new `r1` directory. For visual comparison I redirected its `hands` and `before` requests to the parent assets in the browser, without editing files. All 71 archived images then loaded.

Exercised all eight popover tools, the Show pointer switch, separate keyboard activation of a star, adding seventh/eighth/ninth favorites, removing a favorite, selecting Laser, scrolling the library, scope selection, width chips, color selection, canvas drawing and Keep/Fade/Trail timing. Checked browser drawing in both themes at all three widths, and verified horizontal scrolling at 390. The width chips correctly produced 3, 6, 10 and 16 pt paths. Keep retained a stroke; Fade reduced whole-stroke opacity after the chosen delay. Trail failed the behavior check described below.

This is a mockup review. Static alternative states are acceptable; a fully functioning settings application is unnecessary. But an unopened More button does not prove the design of the recovery or inheritance workflow it is meant to replace. Browser accessibility checks are not native VoiceOver testing. No app launch, native input, live smoke script, build, commit, delegation or hosted CI was performed. Apart from requested temporary browser captures, this review is the only file created.

## Scores by section

Same eight sections and unweighted mean as round 1. Scores consider task clarity, retained capability, understandable icons, state/recovery, keyboard access and the quality of the comparison.

| Section | Score / 100 | Assessment |
| --- | ---: | --- |
| 01 Menu bar | 79 | Clearer visibility and permission repair; history survives Cursor. Capture and rejected-command states remain unspecified. |
| 02 Floating toolbar | 83 | Current-tool face, open picker and fixed context width work. Redo and sound state need attention. |
| 03 Pointers | 62 | Better inspector and effects grouping, undermined by clipped catalog, false non-hand previews and incomplete inheritance. |
| 04 Tools | 70 | Useful width chips, numeric values and local drawing. Trail still demonstrates a different behavior from the app. |
| 05 Shortcuts | 66 | Safer examples and restored groups. Suggested application and command coverage are not internally consistent. |
| 06 Presets & backup | 75 | Persistent Undo and separate Now/Apply are real improvements. Backup boundaries and recovery review remain unseen. |
| 07 First run | 72 | Better pictures and four-step navigation. The wheel gesture and return-to-Cursor lesson still lack shown instruction. |
| 08 Quick controls | 85 | Both mode states are clear and labels remain useful. Idempotent Cursor semantics and assignment states need specification. |

## Round 1 P1 disposition

“Partly resolved” includes cases where the original blocker is fixed but a smaller residual issue remains. It does not mean every residual finding below is still P1.

| Round 1 finding | Status | Verified result and remaining gap |
| --- | --- | --- |
| P1-01 Missing pointer controls/catalog | partly resolved | Tap-sound switch, volume, motion, More buttons, gesture edit badges and a hidden tile are present. Global mute is absent; menu contents are unseen. The library is clipped, not scrollable, and contains 30 entries under “Search 39.” |
| P1-02 This / All and inheritance | partly resolved | “Defaults” is clearer, and size/sound-choice overrides have dots and named resets. Defaults selection leaves the same customized values and resets visible. Independent shadow, shadow-style and sound-enabled inheritance is not demonstrated. |
| P1-03 Favorites capacity and wheel mapping | partly resolved | Eight toolbar slots and six independent directions are visible. Seventh/eighth stars populate the row, and removing a star leaves the wheel unchanged. Reorder/assignment actions, unavailable entries and differing saved assignments lack shown states. Ninth-star refusal is silent. |
| P1-04 Visibility and readiness | partly resolved | Hand switch and permission-needed example are present; toolbar power is replaced with hand/slash. Off gating differs between mouse and keyboard. Capture progress and rejected tool selection are not shown. |
| P1-05 Shortcut safety | partly resolved | Control-Option recommendations are gone. The wheel example uses a single held Option key and a system conflict is visibly skipped. “Use 3” contradicts the already assigned Show pointer row; no reversible applied result or actual first-run trigger/setup is shown. |
| P1-06 History in Cursor | partly resolved | Popover Undo/Redo/Clear stay visible in Cursor, verified interactively. Toolbar Undo/Clear are stable in both frames. The claimed toolbar Redo control does not exist. The original cleanup blocker is fixed; the Redo remainder is P2. |
| P1-07 Hidden toolbar tools/moving actions | resolved | Closed Pen and open Arrow faces show the current tool. Full picker, white and All colors are visible. Both toolbar bodies measure 578 px, with matching shared-action positions. |
| P1-08 Drawing precision/Trail | partly resolved | White, width slider/value, opacity value, stroke pictures and persistent advanced button are drawn. Chips and drawing work. Slider precision is static; Trail still erases only after release and no other annotation type can be tried. |
| P1-09 Preset management/recovery | partly resolved | Persistent Undo row, per-card More, explicit Apply, Now and backup disclosures are present. Their contents, import review, restore review and restart durability are not shown. General is a destination note rather than a mocked page. |
| P1-10 Full shortcut catalog | partly resolved | Shared sidebar, Suggested, group summaries, search and assigned-only icon are present. Only three catalog commands are exposed; closed groups cannot expand. “Pointer 1 of 6” does not account for the current eight pointer commands. |
| P1-11 Targets and keyboard | partly resolved | Swatches and sibling stars measure 28 px before scaling. Space stars a tile without selecting it. Time pills, fake sliders, shortcut recorders and favorite assignment/reordering still lack keyboard controls. Group roles/state semantics are inconsistent. |
| P1-12 Narrow review rendering | resolved | Pairs stack below 900. Settings scale no lower than 0.75; toolbar floor is 0.85. At 390 the five mock containers scroll horizontally and the document itself does not overflow. A scroll cue remains a P2 improvement. |

## P0

None. No catastrophic defect was demonstrated in this unshipped proposal.

## Remaining and new P1 findings

### R2-P1-01 · Pointers · The full catalog is still inaccessible, and Laser previews the wrong pointer

At 1100, `.gridwrap` has a 468 px viewport over 522 px of content, with `overflow:hidden`. Wheel scrolling leaves its scroll position at zero. The last row, including Presentation, is clipped. Thirty tiles are created while the search placeholder advertises 39. Spotlight appears in the grid, but its existence does not establish complete library coverage.

Selecting Laser changes the inspector title to “Laser dot” while the preview and This thumbnail remain Lavender. `syncInsp` explicitly substitutes Lavender for Laser, Spotlight and Presentation. Showing hand size, shadow and gesture controls for all of these also avoids the pointer-specific control policy already present in `PointerCustomization.swift`.

Evidence: `index.html:157`, `index.html:958`, `index.html:1027`.

**Fix:** Make the library genuinely scrollable, render the complete catalog and derive its count. Show the last row reachable. Give Laser and Spotlight/Presentation their own truthful preview and applicable inspector controls. Add a missing-artwork state rather than substituting a healthy hand.

### R2-P1-02 · Pointers · Independent inheritance is still collapsed into combined rows

This/Defaults is a better name, but selecting Defaults leaves Lavender, 15%, Pop, “Use default size, 13%” and “Use default sound, Thock” unchanged. There is no coherent Defaults frame. Shadow enabled/style share one row without distinct override states; tap sound enabled/choice share one dot and one reset that specifically names the sound choice. A person still cannot predict which value a reset restores.

The current customization code treats size, shadow enabled, shadow style, sound enabled and sound choice as separate overrides. This is a preservation requirement.

**Fix:** Show a genuine Defaults frame with inherited values and no per-pointer reset affordances. Show a mixed This frame with separate reset actions for every independently overridable value. Split the combined rows or attach the reset directly to the affected subcontrol. One static expanded example is enough if the other states are explicitly specified.

### R2-P1-03 · Tools · Trail demonstrates the wrong timing and hides the pen/other-mark distinction

During a held Trail stroke, the entire line remained visible after 1.4 seconds. Erasure started only after release. The code calls `finish` on pointer-up and uses the generic seconds value to determine erasure duration. Current `PresentationSettings.swift:35` defines the start of a pen line erasing **as you draw**, with other marks fading as a whole. Trail delay and speed are separate controls.

The heading “After drawing” reinforces the incorrect behavior. The remaining clock/chips do not say whether they control a pen tail or other marks. The canvas offers no tool picker to demonstrate an Arrow or Text mark in Trail.

**Fix:** Call the group “Behavior.” Demonstrate a long held pen stroke losing its beginning before release. In Trail, label the seconds row “Other marks fade after” and show distinct delay/speed controls in the advanced state. Add a compact practice tool picker with at least Pen and Arrow, then demonstrate the arrow fading as a whole.

### R2-P1-04 · Pointers and presets · Closed menus do not yet establish the restored management and recovery workflows

The new destinations are plausible, but their contents are still unseen. Pointer More only advertises hide/rename/remove/restore in its accessible name/title. Gesture artwork and trigger editing, motion More and preset More have no shown open state. Global app mute, currently independent of volume, has no assigned control. A plain speaker SVG next to the slider is not a mute button.

Presets restores a durable-looking Undo row and better apply state. However, “What's included” and “Recovery copies” have no expanded content, and Import has no review state. The backup row says “Presets + Artwork,” leaving the treatment of current settings and excluded shortcuts/capture folders unclear. “Reset All Settings moves to General” is a design note inside the proposed product, not evidence of its new home.

**Fix:** Add small open-menu/state frames for pointer/gesture actions and app-wide motion, including remove/restore recovery and a real app mute control. Show the preset menu, backup inclusion/exclusion disclosure, import review and recovery-copy review. Show Reset in General. These can be concise secondary frames; they need not clutter the default page.

### R2-P1-05 · Shortcuts · The suggested transaction and catalog disagree with the shown state

Suggested says “empty keys only” and “Use 3,” but Show pointer already has the identical assigned shortcut in the catalog below. Quick controls is off and drawing has zero assignments. With Screenshot skipped, the shown state offers only two new assignments. There is no after state naming what changed, what stayed assigned and how to undo the batch.

The catalog is a structure rather than verified full coverage. The current `ShortcutsSettings.swift` pointer array contains eight commands; the mock says six. Mode toggle, separate pointer exit, sound and both gestures need explicit accounting. Group titles and “Search 31” cannot establish that those commands or the Settings shortcut survived. The three displayed recorder fields do not edit and the other groups do not open.

**Fix:** Derive the eligible count from the displayed assignments. Mark existing matches as Already set and show a result such as “2 added, 1 already set, 1 skipped” with Undo. Expose an expanded complete catalog or a supplementary command map with matching counts. Include one recorder/conflict state and preserve the separate mode-toggle command.

### R2-P1-06 · Menu bar · Visibility, readiness and selection still lack one consistent state contract

Show pointer now visibly turns off, which fixes the largest omission. But off is implemented by reducing opacity and blocking pointer events on the tool/hand rows. Those controls remain enabled and keyboard-focusable. I focused Pen and pressed Space while off; the selected tool changed. The review caption still reads Ready. The no-permission frame retains a selected Arrow but does not distinguish “selected for later” from “currently drawing.” Neither frame covers capture in progress or a rejected tool change.

Current controls allow choosing a pointer/tool while hidden and explicitly distinguish selected from ready. A redesign can choose a different policy, but mouse and keyboard must agree.

**Fix:** Allow configuration while hidden and show “Pointer hidden” with the remembered selection, or disable the same controls for every input method. Show a compact selected-versus-ready indication for permission and capture states. Add one capture frame and one rejected-selection result that retains the actual active tool.

### R2-P1-07 · Keyboard access · Labels and larger stars fix only part of the interaction model

Sibling star buttons are a verified fix. The remaining central controls still have no demonstrated keyboard route. “Drag, or use Move Left and Move Right” exists only in a favorite-row hover title; there are no such actions to inspect. Wheel assignment is a single `role=img` diagram with “drag to change.” Fade seconds are clickable, unfocusable spans. Sliders are decorative divs, recorder bodies are spans, and radiogroups contain pressed buttons rather than radio semantics. Ink tabs use `aria-pressed` instead of tab selection state. Width chips also lack the custom visible focus treatment given to the stars and swatches.

**Fix:** Show the favorite action menu with Move Left/Right and a named direction-assignment control. Use focusable buttons for timing, actual sliders/recorders for value editing, and consistent segmented/radio/tab semantics. Include one focused control state and specify arrow-key behavior. For native implementation, preserve standard accessibility values and alternatives to dragging; this review does not claim the native app currently fails them.

## Remaining and new P2 findings

| ID | Finding | Concrete fix |
| --- | --- | --- |
| R2-P2-01 | Toolbar Redo is absent in both states, contrary to the response. Undo and Clear are present and stable. | Add a stable Redo button or a visible history-menu affordance with Redo. Keep the 578 px positioning discipline. |
| R2-P2-02 | Tap-sound icons have the right subject, but the popover/toolbar show no enabled, muted or app-muted state. The wheel's Color icon is still a dotted color disk, not the promised palette treatment. | Show hand-sound/slashed-hand-sound states, with app mute explained in help. Use the same palette/submenu cue across the toolbar and wheel. |
| R2-P2-03 | Favorites capacity is visible and stable directions are a good correction. A ninth star silently does nothing. The wheel map has no direction names, unavailable assignment example or visible explanation that unstarring does not remove its wheel slot. | At capacity show a short “8 favorites” message with Manage. Label the map's directions on editing/focus, retain unavailable slots, and show one differing saved toolbar/wheel assignment state. |
| R2-P2-04 | Width precision and opacity are drawn but cannot be exercised beyond the four chips. The canvas has no Undo, and white ink disappears on its light background. | Connect the 2–20 pt slider/value and opacity control, show a saved custom width such as 13 pt, retain practice Undo, and provide a dark/pattern canvas background. A labeled static custom-value frame is acceptable for design review. |
| R2-P2-05 | First run now has better pictures and four step icons, and removes the premature visible Nice badge. “Hold & flick” still names neither what to hold nor release-to-select; Quick controls starts unassigned. Only the Draw lesson is shown. | When unassigned, offer Set up quick controls. When assigned, display the actual modifier. Show hold, move, release and center/Escape cancellation. Add the click-through and return-to-Cursor lesson frames. |
| R2-P2-06 | Narrow mock containers really scroll, but at 390 the inspector, shortcut keycaps and several toolbar actions initially sit offscreen with no cue. The before images still shrink much more than the after frames. | Add a small horizontal-scroll cue and an optional 100% detail view. Compare one editing task at equal scale, especially Pointers, instead of relying on three miniature before windows. |
| R2-P2-07 | Dark controls render well, but the standalone review shell remains white under the requested direct-file rendering. Pale After labels have about 2.4:1 contrast on white. The dark shell CSS requires `body.standalone`, which this file does not set by default. | Apply the document dark tokens to the actual direct-file body state, with a matching stage background and readable After label. Verify the same URL used by the capture script. |
| R2-P2-08 | Tools has the correct sidebar name and labeled tabs, but no Magnifier/Capture content or permission/destination state. The two wheel roots improve state coverage, but Cursor's idempotence is still unspecified. | Add one compact Capture and Magnifier settings state. Specify that Cursor always selects app interaction, including repeated selection, while the separate shortcut may toggle modes. |

## Verdict

**Revise.** Keep the current toolbar, real artwork, labeled behavior choices, shared Settings frame, stable wheel directions and persistent preset Undo. Close the library and inheritance defects, demonstrate the correct Trail behavior, and provide the missing safe-change and keyboard states before implementation approval. The remaining work is concentrated enough to resolve with a few deliberate secondary frames rather than another broad visual redesign.
