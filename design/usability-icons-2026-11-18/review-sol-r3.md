# Usability and icons review, Sol round 3

**Overall: 83/100. Verdict: revise.**

This is a substantial improvement over round 2's 74. The proposal now shows most of the controls and recovery paths it previously only promised. The toolbar is stable, the full library scrolls, individual setting rows are clearer, and Trail finally demonstrates erasure during drawing. Three consequential errors still prevent approval: Defaults can acquire a selected pointer's name without leaving global scope, Presentation previews the wrong pointer, and Suggested recommends an unsupported wheel trigger.

## Scope and evidence

Read `review-sol-r1.md` and `review-sol-r2.md` before reviewing the current HTML. Compared the revised pages with the archived round 2 Tools, Shortcuts, Presets and Pointers frames. The archived file still generates some hand URLs under `design/hands`; I corrected those requests in the browser for the Pointers comparison, without editing the archive. The current proposal has no broken images.

Used `/private/tmp/lhp-usability-tools/node_modules/playwright-core` with `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, following the section capture and interaction approach in the supplied scripts. Rendered and inspected all eight sections at **1100, 728 and 390 CSS pixels, in light and dark**. All six current-page runs reported zero page/console errors. Screenshots stayed in memory. No capture files or test scripts were saved.

Exercised library scrolling, hand and non-hand selection, Defaults/This transitions, independent mouse and keyboard configuration while hidden, app mute, favorite capacity and unstarring, range controls, timing buttons, practice Undo, white ink background, the advanced disclosure, a held Trail stroke, and whole-arrow fading in Trail. Repeated favorite/keyboard, local drawing/Undo, horizontal scrolling and document-shell checks across all six width/theme combinations. Checked current Swift and glossary definitions for pointer types, independent overrides, wheel triggers, drawing timing, shortcut counts and direction assignments.

Static secondary frames count as design evidence. I accepted the new menus, recorder state, import sheet and recovery list without requiring a functioning native settings app. Browser checks do not establish native VoiceOver support. No app launch, native input, live-smoke, delegation, build, commit or hosted CI occurred. This review file is the only authored file created.

## Scores by section

Same criteria and unweighted mean as earlier rounds: task clarity, retained capability, understandable icons, state/recovery, keyboard access and comparison quality.

| Section | Score / 100 | Assessment |
| --- | ---: | --- |
| 01 Menu bar | 84 | Hidden configuration now works equally with mouse and keyboard. Permission intent is clearer. Capture/rejection states and tap-sound feedback remain incomplete. |
| 02 Floating toolbar | 89 | Redo is present. Both bodies measure 611 px, with identical shared-action positions. Current-tool faces, palette and full picker remain useful. |
| 03 Pointers | 77 | Complete scrollable library, clearer independent rows and useful action frames. Global scope can become misleading, and Presentation is still falsely depicted. |
| 04 Tools | 87 | Correct held-stroke Trail demonstration, whole-arrow fading, precise width/opacity and practice Undo. Advanced values and some preview controls lack truthful feedback. |
| 05 Shortcuts | 78 | Correct category counts, all eight Pointer commands, a recorder frame and a coherent reversible result. The suggested fn trigger is unsupported. |
| 06 Presets & backup | 89 | Management, inclusion/exclusion, import review and persistent recovery now have visible designs. A few backup boundaries and restore consequences need clearer wording. |
| 07 First run | 72 | The drawing lesson is concise. Hold plus a dashed plus sign still fails to explain setup or the gesture, and the other lessons remain unseen. |
| 08 Quick controls | 88 | Palette icon improves Color, short labels survive, and both mode states are clear. Direction editing and repeated Cursor selection need a final specification. |

## Round 2 P1 disposition

“Resolved at proposal level” accepts static frames and does not claim native implementation is complete. Smaller residuals are ranked P2 below rather than keeping an entire former blocker open.

| Round 2 finding | Status | Verified result and remainder |
| --- | --- | --- |
| R2-P1-01 Catalog and non-hand previews | Partly resolved | 39 tiles and derived Search 39. The library has a 468 px viewport over 723 px of content, scrolls to 255 px, and exposes the final row. Laser has a dot preview; non-hand rows hide shadow, shadow style and gestures. Presentation still shares Spotlight's exact circle preview. Missing-artwork treatment is not shown. |
| R2-P1-02 Independent inheritance | Partly resolved | Initial Defaults correctly shows Pointer defaults, 13%, Thock, no reset buttons and no override dots. Five independently overridable values occupy separate rows; size and sound choice demonstrate overrides. Selecting another pointer while Defaults is active replaces the global title with that pointer's name. Defaults also retains per-hand gesture controls and loses shadow controls when entered from a non-hand. |
| R2-P1-03 Trail behavior | Resolved at proposal level | Behavior heading, Pen/Arrow picker, distinct other-mark timing and open advanced card are present. During a held pen stroke, visible length fell from about 142 px to 41 px during a further 650 ms pause before release. The Arrow retained identical geometry while its whole opacity fell, then disappeared. Tail speed fidelity remains P2. |
| R2-P1-04 Management and recovery | Resolved at proposal level | Open pointer, favorite, gesture and motion menus are shown. App mute changes both pressed state and speaker glyph. Preset menu, inclusion list, import review with recovery copy, durable recovery list and General reset home are visible. These frames are sufficient to establish the proposed destinations. |
| R2-P1-05 Suggested transaction and catalog | Partly resolved | Add 2, Already set, skipped conflict and the result with Undo now agree. Counts match the current 8/5/4/7/2 command groups, and Pointer exposes every command. The suggestion now uses fn, which the current trigger picker cannot assign. Closed secondary groups still need a compact command map. |
| R2-P1-06 Hidden/readiness contract | Core resolved; P2 handoff remainder | Mouse selects Pen while hidden; keyboard Space selects Cursor while hidden. Both retain Pointer hidden · choices kept and stable history controls. The no-access Arrow has a dashed kept-for-later treatment. Capture/rejection frames are still absent; they can be specified as retained native states rather than fully simulated here. |
| R2-P1-07 Keyboard and control semantics | Resolved at proposal level | Native HTML ranges, keyboard-operable timing buttons, pressed groups, selected tabs and visible focus rules replace decorative controls. A static Type keys recorder and favorite Move left/right menu are acceptable proposal evidence. The actual direction submenu and native accessibility contract remain P2 details. |

## P0

None found.

## P1 findings

### R3-P1-01 · Pointers · Defaults still loses a trustworthy scope boundary

Reproduction: start with Lavender, choose Defaults, then select Cursor glove in the library. The inspector title becomes Cursor glove while Defaults stays selected, 13% and Thock remain, and resets remain hidden. The name now suggests a per-pointer edit while the selected scope says global. This is the exact distinction the redesign needs to make safe.

There are two related contradictions. The initial Pointer defaults frame still contains Lavender's two gesture artwork editors even though gesture slots belong to individual hands. Enter Defaults after selecting Presentation or Laser and the shared shadow rows disappear because the inspector retains the selected pointer's non-hand policy.

Evidence: `index.html:1129` and `index.html:1146`; reproduced in the browser and inspected as rendered inspector frames.

**Fix:** Make Defaults a distinct inspector state with a stable title and global control policy. Remove per-pointer favorites, management and gesture editors from that state. Choosing a library entry should either explicitly return to This or leave the global inspector intact. Show both transitions. A pair of static frames with that rule is sufficient; implementing persistent settings is unnecessary for this review.

### R3-P1-02 · Pointers · Presentation still advertises Spotlight's appearance

Selecting Spotlight and Presentation produces the same `prev spot` class and the same `#i-spot` artwork. Both library entries use that circle too. Presentation is the telescoping rod pointer, so the thumbnail and preview communicate a different effect from the one being chosen. This is a recognition failure in the central picture-led library, not a request for native rendering fidelity.

Laser is fixed. Do not count that success as coverage for both other types.

Evidence: `index.html:1082` and `index.html:1133`; `docs/GLOSSARY.md` defines Presentation pointer separately from Spotlight.

**Fix:** Give Presentation its rod artwork in the library, This control and preview. Keep Spotlight's dimmed-field/circular opening treatment separate. Show the three non-hand inspector states together once, using each type's applicable size label and controls.

### R3-P1-03 · Shortcuts · The supposedly checked suggestion cannot be assigned

The Quick controls suggestion now shows hold fn. `RadialTrigger` in `Sources/TinyHand/RadialInput.swift:286` supports Option, Control, Shift and Command. `ShortcutsSettings.swift:105` uses that enum in the actual modifier picker. There is no fn option. The explanatory conflict-check note cannot make an unsupported assignment valid.

The batch count and reversible result are good fixes. Keep them, but use an assignment the app can actually store and open with.

**Fix:** Show one supported single modifier, with its real eligibility/conflict treatment, or offer Choose key… and exclude it from Add 2 until chosen. If fn support is an intentional product expansion, explicitly specify that change and its system-key behavior instead of presenting it as an existing checked option.

## P2 findings

| ID | Remaining issue | Concrete fix |
| --- | --- | --- |
| R3-P2-01 | First run's Hold + tile reads like an instruction to hold the plus key. The dashed border does not explain “unassigned,” and the tile is not a setup control. Only Draw is demonstrated. | Use Set up quick controls when unassigned, then show the actual assigned key and hold, move, release. Add small click-through, return-to-Cursor and cancel lesson frames. Keep the lesson optional. |
| R3-P2-02 | Correct shortcut counts establish category coverage, but Presenting, Drawing, Tool keys, Quick controls, Toolbar and Stream Deck remain closed, nonexpanding summaries. Settings, capture-region, Match ink and toolbar position still have no inspectable destination inside those groups. | Add a compact expanded catalog or supplementary command map. Use the same recorder design already shown; no need to wire every row. Include both hold-to-open and persistent Open Quick controls. |
| R3-P2-03 | The favorite menu names Wheel direction but shows no submenu. The small map draws six evenly spaced positions, including south, while the current pointer submenu reserves south for Back and has six saved named directions. No unavailable slot is demonstrated. | Show the actual named direction submenu, selected direction, swap behavior and one unavailable saved assignment. Draw the map to match those positions. Preserve the verified rule that unstarring leaves its wheel slot intact. |
| R3-P2-04 | Some newly real ranges still give false value feedback. Keyboard changes produced app volume 40 with a 100% label, tail speed 600 with a 240 pt/s label, and smoothing 4 with Light unchanged. Tail speed does not drive the age-filtered Trail preview. Clear practice also leaves its sample untouched. | Update the visible values and connect the demonstrated behavior, or label those examples as static states. Wire Clear to the local canvas. Keep the verified 13 pt width, 40% opacity and Undo behavior. Do not imply all ranges have been behaviorally verified. |
| R3-P2-05 | Capture-in-progress and rejected-selection feedback are still unseen. Repeated Cursor selection in the wheel has no written action contract. These are handoff gaps, not reasons to require an app launch for this proposal. | Add a short state note or two small frames: capture progress/cancel; rejection reason with acknowledged tool retained. State that Cursor always enables app interaction, while Cursor ↔ last tool remains the separate toggle command. |
| R3-P2-06 | Tap-sound controls in the popover and toolbar still show only one state. App mute exists in Settings, but the relationship between muted output and a pointer's enabled sound is not visible at those quick entry points. | Show enabled, pointer-muted and app-muted variants with clear help. Preserve per-pointer sound flags when app mute changes. |
| R3-P2-07 | The document shell now switches correctly and horizontal containers scroll at 390, but Shortcuts is the one overflowing mock without a scroll cue. Pointers still compares three tiny before windows with one much larger after. | Add the missing Shortcuts cue. Include one equal-scale before/after editing task or 100% detail view, while retaining the overview. The Mac app does not need a phone layout. |
| R3-P2-08 | Recovery copies now have a convincing durable list, but Restore… does not show what it replaces. The backup exclusions omit display/window positions, and custom gesture artwork is not explicit. Recovery count says 3 while only two copies appear. | Add a compact restore review that identifies scope and preserves a recovery route. Name gesture artwork and the protected local positions in What's included. Show the third copy or an obvious continuation. |
| R3-P2-09 | The secondary frames use fixed dark red Remove/Reset text and muted menu annotations that are harder to read in dark appearance. Several toolbar icons have accessible labels but no hover help in the mock. | Use theme-aware destructive and secondary text colors. Add the proposed help text for icon-only quick actions, especially tap sound, visibility and Match pointer. Keep essential setup instructions visible. |

## Verdict

**Revise.** Keep the visual direction and the new secondary frames. Most round 2 blockers are closed at a reasonable proposal standard. Resolve the three P1 errors with a consistent Defaults state, truthful Presentation artwork and a supported suggested trigger. The remaining work is a focused correction, not another redesign.
